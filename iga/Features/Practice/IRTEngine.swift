// IGA/Features/Practice/IRTEngine.swift

import Foundation

// MARK: - IRT Selection Mode

/// Item selection strategy for IRT engine
enum IRTSelectionMode: Sendable {
    case learning    // Target ~70% accuracy (zone of proximal development)
    case assessment  // Target ~50% accuracy (maximum information)
    case review      // Mixed difficulty for consolidation
}

// MARK: - Session History

/// Tracks state within a practice session
struct SessionHistory: Sendable {
    var seenQuestionIDs: Set<String> = []
    var subskillCounts: [String: Int] = [:]
    var attempts: [AttemptSummary] = []

    mutating func recordAttempt(_ attempt: AttemptSummary, question: Question) {
        seenQuestionIDs.insert(question.id)
        subskillCounts[question.primarySubskill, default: 0] += 1
        attempts.append(attempt)
    }
}

// MARK: - Content Constraints

/// Constraints for item selection
struct ContentConstraints: Sendable {
    var maxPerSubskill: Int = 10
    var minPerSubskill: Int = 2
    var maxExposure: Int = 100  // Global item exposure cap
    var targetAccuracyLearning: Double = 0.70
    var targetAccuracyAssessment: Double = 0.50
    var accuracyTolerance: Double = 0.15

    static let `default` = ContentConstraints()

    static let diagnostic = ContentConstraints(
        maxPerSubskill: 5,
        minPerSubskill: 1,
        targetAccuracyLearning: 0.70,
        targetAccuracyAssessment: 0.50
    )
}

// MARK: - IRT Engine

/// Item Response Theory engine for adaptive question selection and ability estimation
/// Uses 3-Parameter Logistic (3PL) model with Expected A Posteriori (EAP) estimation
actor IRTEngine {

    // MARK: - Configuration

    /// Number of quadrature points for EAP estimation
    private let quadraturePoints: Int = 81  // -4 to +4 in 0.1 increments

    /// Default prior for ability estimation
    private let defaultPrior: (mu: Double, sigma: Double) = (0.0, 1.0)

    // MARK: - 3PL Probability Model

    /// Calculate probability of correct response given ability
    /// P(correct | θ, a, b, c) = c + (1-c) / (1 + exp(-a(θ - b)))
    func probabilityCorrect(theta: Double, question: Question) -> Double {
        let a = question.irtA
        let b = question.irtB
        let c = question.irtC
        let exponent = -a * (theta - b)
        return c + (1 - c) / (1 + exp(exponent))
    }

    /// Calculate probability using raw parameters
    func probabilityCorrect(theta: Double, a: Double, b: Double, c: Double) -> Double {
        let exponent = -a * (theta - b)
        return c + (1 - c) / (1 + exp(exponent))
    }

    // MARK: - Fisher Information

    /// Calculate Fisher information at given theta for an item
    /// I(θ) = a² × ((P - c)/(1 - c))² × ((1-P)/P)
    func fisherInformation(theta: Double, question: Question) -> Double {
        let p = probabilityCorrect(theta: theta, question: question)
        let a = question.irtA
        let c = question.irtC

        // Guard against edge cases
        guard p > c && p < 1 else { return 0 }

        let pMinusC = p - c
        let oneMinusC = 1 - c
        let q = 1 - p

        return pow(a, 2) * pow(pMinusC / oneMinusC, 2) * (q / p)
    }

    /// Calculate total information for a set of items at theta
    func totalInformation(theta: Double, questions: [Question]) -> Double {
        questions.reduce(0) { $0 + fisherInformation(theta: theta, question: $1) }
    }

    // MARK: - Ability Estimation (EAP)

    /// Estimate ability using Expected A Posteriori with Gaussian prior
    /// Uses numerical integration via quadrature
    func estimateAbility(
        attempts: [AttemptSummary],
        questions: [String: Question],
        prior: (mu: Double, sigma: Double)? = nil
    ) -> (theta: Double, se: Double) {
        let priorParams = prior ?? defaultPrior

        // Generate quadrature points
        let points = stride(from: -4.0, through: 4.0, by: 0.1).map { $0 }

        var numerator = 0.0
        var denominator = 0.0
        var secondMoment = 0.0

        for theta in points {
            // Calculate likelihood of response pattern
            var likelihood = 1.0
            for attempt in attempts {
                guard let question = questions[attempt.questionID] else { continue }
                let p = probabilityCorrect(theta: theta, question: question)
                likelihood *= attempt.isCorrect ? p : (1 - p)
            }

            // Prior probability (Gaussian)
            let priorProb = gaussianPDF(theta, mu: priorParams.mu, sigma: priorParams.sigma)

            // Weight = likelihood × prior
            let weight = likelihood * priorProb

            numerator += theta * weight
            secondMoment += theta * theta * weight
            denominator += weight
        }

        // EAP estimate
        let thetaEAP = denominator > 0 ? numerator / denominator : priorParams.mu

        // Calculate posterior variance for SE
        let variance = denominator > 0
            ? (secondMoment / denominator) - (thetaEAP * thetaEAP)
            : priorParams.sigma * priorParams.sigma
        let se = sqrt(max(0.01, variance))  // Floor at 0.01 to avoid numerical issues

        return (thetaEAP, se)
    }

    /// Gaussian probability density function
    private func gaussianPDF(_ x: Double, mu: Double, sigma: Double) -> Double {
        let coefficient = 1.0 / (sigma * sqrt(2 * .pi))
        let exponent = -pow(x - mu, 2) / (2 * sigma * sigma)
        return coefficient * exp(exponent)
    }

    // MARK: - Item Selection

    /// Select next item maximizing Fisher information with constraints
    func selectNextItem(
        theta: Double,
        availableItems: [Question],
        sessionHistory: SessionHistory,
        mode: IRTSelectionMode,
        constraints: ContentConstraints = .default
    ) -> Question? {
        // Filter to eligible items
        let candidates = availableItems.filter { item in
            // Not already seen in session
            !sessionHistory.seenQuestionIDs.contains(item.id) &&
            // Subskill not at max
            (sessionHistory.subskillCounts[item.primarySubskill] ?? 0) < constraints.maxPerSubskill
        }

        guard !candidates.isEmpty else {
            // Fallback: return any unseen item
            return availableItems.first { !sessionHistory.seenQuestionIDs.contains($0.id) }
        }

        // Determine target accuracy based on mode
        let targetAccuracy: Double
        switch mode {
        case .learning:
            targetAccuracy = constraints.targetAccuracyLearning
        case .assessment:
            targetAccuracy = constraints.targetAccuracyAssessment
        case .review:
            targetAccuracy = 0.60  // Slightly challenging but not too hard
        }

        // Score each candidate
        let scored = candidates.map { item -> (Question, Double) in
            var score = 0.0

            // Primary factor: Fisher information at current theta
            let info = fisherInformation(theta: theta, question: item)
            score += info

            // Motivational guardrail: penalize items far from target accuracy
            let p = probabilityCorrect(theta: theta, question: item)
            let accuracyDeviation = abs(p - targetAccuracy)
            if accuracyDeviation > constraints.accuracyTolerance {
                score -= accuracyDeviation * 2.0
            }

            // Content balancing: bonus for underrepresented subskills
            let subskillCount = sessionHistory.subskillCounts[item.primarySubskill] ?? 0
            if subskillCount < constraints.minPerSubskill {
                score += 0.5
            }

            return (item, score)
        }

        // Sort by score and add slight randomization among top choices
        let sorted = scored.sorted { $0.1 > $1.1 }
        let topChoices = Array(sorted.prefix(3))

        return topChoices.randomElement()?.0 ?? candidates.first
    }

    /// Select next item for diagnostic (targets maximum uncertainty reduction)
    func selectDiagnosticItem(
        subskillProgress: [String: (theta: Double, se: Double, count: Int)],
        availableItems: [Question],
        seenQuestionIDs: Set<String>
    ) -> Question? {
        // Find subskill with highest SE that isn't complete
        let incompleteSubskills = subskillProgress
            .filter { $0.value.se >= 0.3 && $0.value.count < 5 }
            .sorted { $0.value.se > $1.value.se }

        guard let targetSubskill = incompleteSubskills.first else {
            return nil  // Diagnostic complete
        }

        // Filter items for this subskill
        let subskillItems = availableItems.filter {
            $0.subskillIDs.contains(targetSubskill.key) || $0.primarySubskill == targetSubskill.key
        }.filter {
            !seenQuestionIDs.contains($0.id)
        }

        guard !subskillItems.isEmpty else {
            // No items for this subskill, try another
            return availableItems.first { !seenQuestionIDs.contains($0.id) }
        }

        // Select item maximizing information at current theta estimate
        let theta = targetSubskill.value.theta
        return subskillItems.max { item1, item2 in
            fisherInformation(theta: theta, question: item1) <
            fisherInformation(theta: theta, question: item2)
        }
    }

    // MARK: - Score Estimation

    /// Convert theta to estimated GRE scaled score (130-170)
    func estimateScaledScore(theta: Double, section: QuestionSection) -> (score: Int, lower: Int, upper: Int) {
        // Calibration lookup table (would be refined with pilot data)
        // Maps theta to approximate scaled score
        let thetaToScore: [(theta: Double, score: Int)]
        switch section {
        case .quant:
            thetaToScore = [
                (-3.0, 130), (-2.0, 140), (-1.0, 148), (0.0, 155),
                (1.0, 161), (2.0, 166), (3.0, 170)
            ]
        case .verbal:
            thetaToScore = [
                (-3.0, 130), (-2.0, 138), (-1.0, 147), (0.0, 153),
                (1.0, 159), (2.0, 164), (3.0, 170)
            ]
        case .awa:
            // AWA uses different scale (1-6)
            return (Int(max(1, min(6, 3.5 + theta))), 1, 6)
        }

        // Linear interpolation
        let score = interpolate(theta: theta, table: thetaToScore)
        let clamped = max(130, min(170, score))

        // Confidence interval (approximately ±1 SE → ±3-5 scaled points)
        let marginOfError = 4
        return (clamped, max(130, clamped - marginOfError), min(170, clamped + marginOfError))
    }

    private func interpolate(theta: Double, table: [(theta: Double, score: Int)]) -> Int {
        // Find surrounding points
        guard let lower = table.last(where: { $0.theta <= theta }),
              let upper = table.first(where: { $0.theta >= theta }) else {
            // Extrapolate
            if theta < table.first!.theta {
                return table.first!.score
            } else {
                return table.last!.score
            }
        }

        if lower.theta == upper.theta {
            return lower.score
        }

        // Linear interpolation
        let fraction = (theta - lower.theta) / (upper.theta - lower.theta)
        let score = Double(lower.score) + fraction * Double(upper.score - lower.score)
        return Int(score.rounded())
    }
}

// MARK: - Convenience Extensions

extension IRTEngine {
    /// Quick ability estimate from a list of attempts and questions
    func quickEstimate(
        correctCount: Int,
        totalCount: Int,
        averageDifficulty: Double = 0.0
    ) -> Double {
        guard totalCount > 0 else { return 0.0 }
        let accuracy = Double(correctCount) / Double(totalCount)

        // Simple logistic transform
        // Accuracy of 0.5 → theta = averageDifficulty
        // Accuracy of 0.75 → theta ≈ averageDifficulty + 1
        // Accuracy of 0.25 → theta ≈ averageDifficulty - 1
        let clampedAccuracy = max(0.01, min(0.99, accuracy))
        let logit = log(clampedAccuracy / (1 - clampedAccuracy))

        return averageDifficulty + logit
    }
}
