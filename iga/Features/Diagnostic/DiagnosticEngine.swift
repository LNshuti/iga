// IGA/Features/Diagnostic/DiagnosticEngine.swift

import Foundation

// MARK: - Subskill Progress

/// Tracks progress within a diagnostic for a single subskill
struct SubskillProgress: Sendable {
    var attempts: [AttemptSummary] = []
    var currentTheta: Double = 0.0
    var currentSE: Double = 1.0

    /// Whether this subskill has sufficient data
    var isComplete: Bool {
        currentSE < 0.3 || attempts.count >= 5
    }

    /// Accuracy on this subskill
    var accuracy: Double {
        guard !attempts.isEmpty else { return 0 }
        let correct = attempts.filter { $0.isCorrect }.count
        return Double(correct) / Double(attempts.count)
    }
}

// MARK: - Diagnostic Engine

/// Manages the adaptive diagnostic assessment
/// Uses IRT to select items and estimate abilities per subskill
actor DiagnosticEngine {
    private let irtEngine = IRTEngine()

    // MARK: - Item Selection

    /// Select the next item for the diagnostic
    /// Targets the subskill with highest uncertainty (SE)
    func selectNextItem(
        progress: [String: SubskillProgress],
        availableItems: [Question],
        seenQuestionIDs: Set<String>
    ) async -> Question? {
        // Find incomplete subskills, sorted by SE (highest first)
        let incomplete = progress
            .filter { !$0.value.isComplete }
            .sorted { $0.value.currentSE > $1.value.currentSE }

        guard let targetSubskill = incomplete.first else {
            return nil  // All subskills complete
        }

        // Filter items for this subskill that haven't been seen
        let subskillItems = availableItems.filter { item in
            !seenQuestionIDs.contains(item.id) &&
            (item.subskillIDs.contains(targetSubskill.key) ||
             item.primarySubskill == targetSubskill.key)
        }

        // If no items for target subskill, try next subskill
        if subskillItems.isEmpty {
            // Try other incomplete subskills
            for subskill in incomplete.dropFirst() {
                let fallbackItems = availableItems.filter { item in
                    !seenQuestionIDs.contains(item.id) &&
                    (item.subskillIDs.contains(subskill.key) ||
                     item.primarySubskill == subskill.key)
                }
                if let item = selectOptimalItem(
                    from: fallbackItems,
                    theta: subskill.value.currentTheta
                ) {
                    return item
                }
            }
            // Last resort: any unseen item
            return availableItems.first { !seenQuestionIDs.contains($0.id) }
        }

        // Select item maximizing information at current theta
        return selectOptimalItem(
            from: subskillItems,
            theta: targetSubskill.value.currentTheta
        )
    }

    /// Select the optimal item from candidates based on Fisher information
    private func selectOptimalItem(from items: [Question], theta: Double) -> Question? {
        guard !items.isEmpty else { return nil }

        // Score by Fisher information
        let scored = items.map { item -> (Question, Double) in
            let info = item.fisherInformation(theta: theta)
            return (item, info)
        }

        // Return item with max information
        return scored.max { $0.1 < $1.1 }?.0
    }

    // MARK: - Answer Processing

    /// Process an answer and update ability estimates
    func processAnswer(
        progress: inout [String: SubskillProgress],
        question: Question,
        attempt: AttemptSummary,
        allQuestions: [String: Question]
    ) async {
        // Update each subskill the question tests
        let subskillsToUpdate = question.subskillIDs.isEmpty
            ? [question.primarySubskill]
            : question.subskillIDs

        for subskillID in subskillsToUpdate {
            var subskillProgress = progress[subskillID] ?? SubskillProgress()

            // Add attempt
            subskillProgress.attempts.append(attempt)

            // Re-estimate theta using EAP
            let (theta, se) = await irtEngine.estimateAbility(
                attempts: subskillProgress.attempts,
                questions: allQuestions,
                prior: (0.0, 1.0)
            )

            subskillProgress.currentTheta = theta
            subskillProgress.currentSE = se

            progress[subskillID] = subskillProgress
        }
    }

    // MARK: - Completion Check

    /// Check if the diagnostic is complete
    func isComplete(progress: [String: SubskillProgress]) -> Bool {
        // All subskills must be complete
        for subskill in Subskill.allCases {
            guard let subskillProgress = progress[subskill.rawValue] else {
                return false  // Missing subskill
            }
            if !subskillProgress.isComplete {
                return false
            }
        }
        return true
    }

    /// Get minimum items remaining (rough estimate)
    func estimatedItemsRemaining(progress: [String: SubskillProgress]) -> Int {
        var remaining = 0
        for subskill in Subskill.allCases {
            let subskillProgress = progress[subskill.rawValue] ?? SubskillProgress()
            if !subskillProgress.isComplete {
                // Estimate items needed: at least 1, max 5 - current count
                let needed = max(1, 5 - subskillProgress.attempts.count)
                remaining += needed
            }
        }
        return remaining
    }

    // MARK: - Result Generation

    /// Generate the final diagnostic result
    func generateResult(
        progress: [String: SubskillProgress],
        totalTimeSeconds: Int
    ) async -> DiagnosticResult {
        var estimates: [String: SubskillEstimate] = [:]

        for (subskillID, subskillProgress) in progress {
            estimates[subskillID] = SubskillEstimate(
                theta: subskillProgress.currentTheta,
                standardError: subskillProgress.currentSE,
                itemCount: subskillProgress.attempts.count,
                accuracy: subskillProgress.accuracy
            )
        }

        // Calculate section averages
        let quantSubskills = Subskill.quantSubskills.map { $0.rawValue }
        let verbalSubskills = Subskill.verbalSubskills.map { $0.rawValue }

        let quantThetas = quantSubskills.compactMap { estimates[$0]?.theta }
        let verbalThetas = verbalSubskills.compactMap { estimates[$0]?.theta }

        let quantAvg = quantThetas.isEmpty ? 0 : quantThetas.reduce(0, +) / Double(quantThetas.count)
        let verbalAvg = verbalThetas.isEmpty ? 0 : verbalThetas.reduce(0, +) / Double(verbalThetas.count)

        // Find weakest areas (lowest theta)
        let weakest = estimates
            .sorted { $0.value.theta < $1.value.theta }
            .prefix(3)
            .map { $0.key }

        return DiagnosticResult(
            subskillEstimates: estimates,
            overallQuantTheta: quantAvg,
            overallVerbalTheta: verbalAvg,
            recommendedFocusAreas: Array(weakest),
            totalTimeSeconds: totalTimeSeconds
        )
    }

    // MARK: - Mastery Initialization

    /// Create initial mastery states from diagnostic result
    func createMasteryStates(from result: DiagnosticResult) async -> [SubskillMasteryState] {
        let bktEngine = BKTEngine()
        var states: [SubskillMasteryState] = []

        for (subskillID, estimate) in result.subskillEstimates {
            // Calculate initial BKT parameters
            let (pKnown, pLearn, pForget) = await bktEngine.initializeMasteryFromDiagnostic(
                subskillID: subskillID,
                theta: estimate.theta,
                se: estimate.standardError,
                attemptCount: estimate.itemCount,
                correctCount: Int(estimate.accuracy * Double(estimate.itemCount))
            )

            let state = SubskillMasteryState(
                subskillID: subskillID,
                thetaEstimate: estimate.theta,
                thetaSE: estimate.standardError,
                pKnown: pKnown,
                pLearn: pLearn,
                pForget: pForget,
                attemptCount: estimate.itemCount,
                correctCount: Int(estimate.accuracy * Double(estimate.itemCount)),
                lastPracticed: Date()
            )

            states.append(state)
        }

        return states
    }
}

// MARK: - Diagnostic State

/// Observable state for the diagnostic UI
enum DiagnosticState: Equatable {
    case notStarted
    case inProgress(questionNumber: Int, totalEstimated: Int)
    case completed(DiagnosticResult)
    case error(String)

    static func == (lhs: DiagnosticState, rhs: DiagnosticState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case let (.inProgress(l1, l2), .inProgress(r1, r2)):
            return l1 == r1 && l2 == r2
        case let (.completed(l), .completed(r)):
            return l.id == r.id
        case let (.error(l), .error(r)):
            return l == r
        default:
            return false
        }
    }
}
