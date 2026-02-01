// IGA/Features/Practice/BKTEngine.swift

import Foundation

// MARK: - BKT Parameters

/// Parameters for Bayesian Knowledge Tracing
struct BKTParameters: Codable, Sendable {
    /// Probability of learning per opportunity P(T)
    var pLearn: Double

    /// Probability of forgetting per day P(F)
    var pForget: Double

    /// Probability of guessing correctly P(G)
    var pGuess: Double

    /// Probability of slipping (error despite knowing) P(S)
    var pSlip: Double

    /// Default parameters based on learning science research
    static let `default` = BKTParameters(
        pLearn: 0.10,
        pForget: 0.02,
        pGuess: 0.25,
        pSlip: 0.10
    )

    /// Conservative parameters (slower learning, faster forgetting)
    static let conservative = BKTParameters(
        pLearn: 0.08,
        pForget: 0.03,
        pGuess: 0.25,
        pSlip: 0.12
    )

    /// Optimistic parameters (faster learning, slower forgetting)
    static let optimistic = BKTParameters(
        pLearn: 0.15,
        pForget: 0.01,
        pGuess: 0.20,
        pSlip: 0.08
    )
}

// MARK: - BKT Engine

/// Bayesian Knowledge Tracing engine for per-subskill mastery tracking
/// Tracks learning and forgetting dynamics alongside IRT ability estimation
actor BKTEngine {

    // MARK: - Forgetting Model

    /// Apply forgetting based on time elapsed since last practice
    /// Uses exponential decay: P(known, t) = P(known, 0) × (1 - pForget)^days
    func applyForgetting(pKnown: Double, daysSince: Double, pForget: Double) -> Double {
        guard daysSince > 0 else { return pKnown }
        let decay = pow(1 - pForget, daysSince)
        return pKnown * decay
    }

    // MARK: - Bayesian Update

    /// Update P(Known) based on observed response
    /// Uses Bayes' theorem with learning transition
    func updatePKnown(
        priorPKnown: Double,
        correct: Bool,
        params: BKTParameters
    ) -> Double {
        // P(obs | known) and P(obs | not known)
        let pObsGivenKnown: Double
        let pObsGivenUnknown: Double

        if correct {
            pObsGivenKnown = 1 - params.pSlip      // Correct because knows
            pObsGivenUnknown = params.pGuess        // Correct by guessing
        } else {
            pObsGivenKnown = params.pSlip          // Wrong despite knowing (slip)
            pObsGivenUnknown = 1 - params.pGuess   // Wrong because doesn't know
        }

        // Bayes' theorem: P(known | obs)
        let numerator = priorPKnown * pObsGivenKnown
        let denominator = numerator + (1 - priorPKnown) * pObsGivenUnknown

        guard denominator > 0 else { return priorPKnown }
        let posterior = numerator / denominator

        // Learning transition: even if didn't know before, might have learned
        let learned = posterior + (1 - posterior) * params.pLearn

        return max(0, min(1, learned))
    }

    // MARK: - Full Mastery Update

    /// Update mastery state after an attempt
    func updateMastery(
        state: SubskillMasteryState,
        correct: Bool,
        responseTimeMs: Int,
        expectedTimeMs: Int,
        timestamp: Date
    ) -> (pKnown: Double, pLearn: Double) {
        // 1. Apply forgetting based on time since last practice
        var currentPKnown = state.pKnown
        if let lastPracticed = state.lastPracticed {
            let daysSince = timestamp.timeIntervalSince(lastPracticed) / 86400.0
            currentPKnown = applyForgetting(
                pKnown: currentPKnown,
                daysSince: daysSince,
                pForget: state.pForget
            )
        }

        // 2. Bayesian update based on response
        let params = BKTParameters(
            pLearn: state.pLearn,
            pForget: state.pForget,
            pGuess: 0.25,
            pSlip: 0.10
        )
        let newPKnown = updatePKnown(
            priorPKnown: currentPKnown,
            correct: correct,
            params: params
        )

        // 3. Adjust learning rate based on response time
        // Fast correct answers suggest stronger learning
        var newPLearn = state.pLearn
        if correct {
            let timeRatio = Double(responseTimeMs) / Double(expectedTimeMs)
            if timeRatio < 0.7 {
                // Fast response: increase learning rate slightly
                newPLearn = min(0.20, state.pLearn * 1.1)
            } else if timeRatio > 2.0 {
                // Slow response: decrease learning rate slightly
                newPLearn = max(0.05, state.pLearn * 0.95)
            }
        }

        return (newPKnown, newPLearn)
    }

    // MARK: - Batch Update

    /// Update mastery for multiple attempts (e.g., after a session)
    func batchUpdate(
        state: SubskillMasteryState,
        attempts: [(correct: Bool, responseTimeMs: Int, expectedTimeMs: Int, timestamp: Date)]
    ) -> (pKnown: Double, pLearn: Double) {
        var currentPKnown = state.pKnown
        var currentPLearn = state.pLearn
        var lastTimestamp = state.lastPracticed

        for attempt in attempts.sorted(by: { $0.timestamp < $1.timestamp }) {
            // Apply forgetting from last timestamp
            if let last = lastTimestamp {
                let daysSince = attempt.timestamp.timeIntervalSince(last) / 86400.0
                currentPKnown = applyForgetting(
                    pKnown: currentPKnown,
                    daysSince: daysSince,
                    pForget: state.pForget
                )
            }

            // Update based on this attempt
            let params = BKTParameters(
                pLearn: currentPLearn,
                pForget: state.pForget,
                pGuess: 0.25,
                pSlip: 0.10
            )
            currentPKnown = updatePKnown(
                priorPKnown: currentPKnown,
                correct: attempt.correct,
                params: params
            )

            // Adjust learning rate
            if attempt.correct {
                let timeRatio = Double(attempt.responseTimeMs) / Double(attempt.expectedTimeMs)
                if timeRatio < 0.7 {
                    currentPLearn = min(0.20, currentPLearn * 1.1)
                }
            }

            lastTimestamp = attempt.timestamp
        }

        return (currentPKnown, currentPLearn)
    }

    // MARK: - Predictions

    /// Predict probability of correct response given mastery state
    func predictCorrect(state: SubskillMasteryState) -> Double {
        let pKnown = state.pKnown
        let pGuess = 0.25
        let pSlip = 0.10

        // P(correct) = P(known) × P(not slip) + P(not known) × P(guess)
        return pKnown * (1 - pSlip) + (1 - pKnown) * pGuess
    }

    /// Predict mastery level after N more correct/incorrect attempts
    func predictFutureMastery(
        state: SubskillMasteryState,
        additionalCorrect: Int,
        additionalIncorrect: Int
    ) -> MasteryLevel {
        var pKnown = state.pKnown
        let params = BKTParameters.default

        // Simulate correct attempts
        for _ in 0..<additionalCorrect {
            pKnown = updatePKnown(priorPKnown: pKnown, correct: true, params: params)
        }

        // Simulate incorrect attempts
        for _ in 0..<additionalIncorrect {
            pKnown = updatePKnown(priorPKnown: pKnown, correct: false, params: params)
        }

        return MasteryLevel.from(pKnown: pKnown)
    }

    /// Estimate attempts needed to reach target mastery level
    func attemptsToMastery(
        currentPKnown: Double,
        targetLevel: MasteryLevel,
        assumedAccuracy: Double = 0.70
    ) -> Int {
        var pKnown = currentPKnown
        let targetPKnown = targetLevel.threshold
        var attempts = 0
        let maxAttempts = 100

        let params = BKTParameters.default

        while pKnown < targetPKnown && attempts < maxAttempts {
            // Simulate an attempt with assumed accuracy
            let isCorrect = Double.random(in: 0...1) < assumedAccuracy
            pKnown = updatePKnown(priorPKnown: pKnown, correct: isCorrect, params: params)
            attempts += 1
        }

        return attempts
    }

    // MARK: - Review Scheduling

    /// Calculate optimal review interval based on mastery
    func optimalReviewInterval(state: SubskillMasteryState) -> Int {
        // Higher mastery = longer intervals
        // Based on spaced repetition research
        switch state.masteryLevel {
        case .novice:
            return 1  // Review daily
        case .developing:
            return 2  // Review every 2 days
        case .proficient:
            return 4  // Review every 4 days
        case .mastered:
            return 7  // Review weekly
        }
    }

    /// Calculate forgetting risk (0-1) for scheduling priorities
    func forgettingRisk(state: SubskillMasteryState, currentDate: Date = Date()) -> Double {
        guard let lastPracticed = state.lastPracticed else {
            return 1.0  // Never practiced = high risk
        }

        let daysSince = currentDate.timeIntervalSince(lastPracticed) / 86400.0
        let decayedPKnown = applyForgetting(
            pKnown: state.pKnown,
            daysSince: daysSince,
            pForget: state.pForget
        )

        // Risk = how much pKnown has dropped
        let drop = state.pKnown - decayedPKnown
        return min(1.0, drop * 2)  // Scale so 0.5 drop = 1.0 risk
    }
}

// MARK: - Convenience Extensions

extension BKTEngine {
    /// Initialize mastery state from diagnostic theta estimate
    func initializeMasteryFromDiagnostic(
        subskillID: String,
        theta: Double,
        se: Double,
        attemptCount: Int,
        correctCount: Int
    ) -> (pKnown: Double, pLearn: Double, pForget: Double) {
        // Map theta to initial pKnown
        // theta: -3 to +3 → pKnown: 0.1 to 0.9
        let basePKnown = 0.5 + (theta / 6.0) * 0.8
        let clampedPKnown = max(0.1, min(0.9, basePKnown))

        // Adjust based on confidence (SE)
        // Lower SE = more confident = use closer to estimate
        // Higher SE = less confident = regress toward 0.5
        let confidence = max(0, 1 - se / 1.0)  // SE of 1.0 = no confidence
        let adjustedPKnown = clampedPKnown * confidence + 0.4 * (1 - confidence)

        // Initial learning rate based on accuracy
        let accuracy = attemptCount > 0 ? Double(correctCount) / Double(attemptCount) : 0.5
        let pLearn: Double
        if accuracy > 0.7 {
            pLearn = 0.12  // Learning fast
        } else if accuracy < 0.4 {
            pLearn = 0.08  // Learning slow
        } else {
            pLearn = 0.10  // Default
        }

        return (adjustedPKnown, pLearn, 0.02)
    }
}
