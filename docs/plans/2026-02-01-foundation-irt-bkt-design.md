# Foundation Design: IRT Engine + BKT + Diagnostic Flow

> **Date**: 2026-02-01
> **Status**: Approved
> **Scope**: Weeks 0-2 of IGA Premium roadmap

## Overview

Replace Elo-based `AdaptiveEngine` with IRT (Item Response Theory) + Bayesian Knowledge Tracing. Add diagnostic flow to establish baseline ability per subskill.

## Decision Log

- **Elo → IRT Migration**: Clean replacement (Option A). No existing users to migrate.
- **Architecture**: Actor-based engines (same pattern as existing `AdaptiveEngine`)
- **Subskill Storage**: String IDs, not relationships (simpler, sufficient)

---

## 1. Expanded Data Models

### New Models

**Subskill** (enum + metadata, not SwiftData)
```swift
enum Subskill: String, CaseIterable, Codable {
    // Quant
    case qArithmetic = "Q-AR"
    case qAlgebra = "Q-AL"
    case qGeometry = "Q-GE"
    case qWordProblems = "Q-WP"
    case qDataAnalysis = "Q-DA"
    // Verbal
    case vSentenceEquiv = "V-SE"
    case vTextCompletion = "V-TC"
    case vRCDetail = "V-RC-D"
    case vRCStructure = "V-RC-S"

    var name: String { ... }
    var section: Section { ... }
    var description: String { ... }
}
```

**SubskillMasteryState** (SwiftData @Model)
```swift
@Model
final class SubskillMasteryState {
    @Attribute(.unique) var id: UUID
    var subskillID: String           // "Q-AL"

    // IRT state
    var thetaEstimate: Double        // ability estimate
    var thetaSE: Double              // standard error

    // BKT state
    var pKnown: Double               // P(L) - probability known
    var pLearn: Double               // learning rate
    var pForget: Double              // forgetting rate

    // Stats
    var attemptCount: Int
    var correctCount: Int
    var lastPracticed: Date?

    // Derived
    var masteryLevel: MasteryLevel   // computed from pKnown
}

enum MasteryLevel: Int, Codable {
    case novice = 0      // pKnown < 0.40
    case developing = 1  // 0.40 <= pKnown < 0.65
    case proficient = 2  // 0.65 <= pKnown < 0.85
    case mastered = 3    // pKnown >= 0.85
}
```

**Attempt** (SwiftData @Model)
```swift
@Model
final class Attempt {
    @Attribute(.unique) var id: UUID
    var questionID: UUID
    var sessionID: UUID
    var selectedAnswer: Int?
    var isCorrect: Bool
    var responseTimeMs: Int
    var hintsUsed: Int
    var timestamp: Date

    // Ability tracking
    var thetaBefore: Double?
    var thetaAfter: Double?
    var subskillID: String
}
```

**DiagnosticResult** (SwiftData @Model)
```swift
@Model
final class DiagnosticResult {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var subskillEstimates: [String: SubskillEstimate]  // encoded as Data
    var overallQuantTheta: Double
    var overallVerbalTheta: Double
    var recommendedFocusAreas: [String]
    var totalTimeSeconds: Int
}

struct SubskillEstimate: Codable {
    let theta: Double
    let standardError: Double
    let itemCount: Int
    let accuracy: Double
}
```

### Modified Models

**Question** - Add IRT parameters:
```swift
// New fields
var subskillIDs: [String]              // ["Q-AL", "Q-AR"]
var irtA: Double                       // discrimination (default 1.0)
var irtB: Double                       // difficulty (default 0.0)
var irtC: Double                       // guessing (default 0.2)
var timeBenchmarkSeconds: Int          // expected solve time (default 90)
var distractorRationales: [String: String]  // choiceIndex → rationale
```

**UserProgress** - Add diagnostic tracking:
```swift
// New fields
var diagnosticCompletedAt: Date?
var lastDiagnosticID: UUID?
```

---

## 2. IRT Engine

**File**: `iga/Features/Practice/IRTEngine.swift`

**Actor-based, stateless calculations.**

### Core Functions

```swift
actor IRTEngine {

    // 3PL probability model
    // P(correct | θ, a, b, c) = c + (1-c) / (1 + exp(-a(θ - b)))
    func probabilityCorrect(theta: Double, question: Question) -> Double {
        let a = question.irtA
        let b = question.irtB
        let c = question.irtC
        let exponent = -a * (theta - b)
        return c + (1 - c) / (1 + exp(exponent))
    }

    // Fisher information at θ for item
    // I(θ) = a² × ((P - c)/(1 - c))² × ((1-P)/P)
    func fisherInformation(theta: Double, question: Question) -> Double {
        let p = probabilityCorrect(theta: theta, question: question)
        let a = question.irtA
        let c = question.irtC

        guard p > c && p < 1 else { return 0 }

        let numerator = pow(a, 2) * pow((p - c) / (1 - c), 2)
        let denominator = p * (1 - p)
        return numerator * (1 - p) / p
    }

    // EAP ability estimation with Gaussian quadrature
    func estimateAbility(
        attempts: [Attempt],
        questions: [UUID: Question],
        prior: (mu: Double, sigma: Double) = (0.0, 1.0)
    ) -> (theta: Double, se: Double) {
        // Quadrature points from -4 to +4
        let points = stride(from: -4.0, through: 4.0, by: 0.1).map { $0 }

        var numerator = 0.0
        var denominator = 0.0

        for theta in points {
            let likelihood = attempts.reduce(1.0) { result, attempt in
                guard let question = questions[attempt.questionID] else { return result }
                let p = probabilityCorrect(theta: theta, question: question)
                return result * (attempt.isCorrect ? p : (1 - p))
            }

            let priorProb = gaussianPDF(theta, mu: prior.mu, sigma: prior.sigma)
            let weight = likelihood * priorProb

            numerator += theta * weight
            denominator += weight
        }

        let thetaEAP = denominator > 0 ? numerator / denominator : prior.mu

        // Calculate SE from Fisher information
        let totalInfo = attempts.compactMap { questions[$0.questionID] }
            .reduce(0.0) { $0 + fisherInformation(theta: thetaEAP, question: $1) }
        let se = totalInfo > 0 ? 1.0 / sqrt(totalInfo) : 1.0

        return (thetaEAP, se)
    }

    // Item selection maximizing Fisher information with constraints
    func selectNextItem(
        theta: Double,
        availableItems: [Question],
        sessionHistory: SessionHistory,
        mode: SessionMode,
        constraints: ContentConstraints
    ) -> Question? {
        let candidates = availableItems.filter { item in
            !sessionHistory.seenQuestionIDs.contains(item.id) &&
            (sessionHistory.subskillCounts[item.primarySubskill] ?? 0) < constraints.maxPerSubskill
        }

        guard !candidates.isEmpty else { return availableItems.first }

        let targetAccuracy = mode == .learning ? 0.70 : 0.50

        let scored = candidates.map { item -> (Question, Double) in
            let info = fisherInformation(theta: theta, question: item)
            let p = probabilityCorrect(theta: theta, question: item)

            // Penalties
            let accuracyDeviation = abs(p - targetAccuracy)
            let motivationPenalty = accuracyDeviation > 0.15 ? accuracyDeviation * 2 : 0

            let subskillCount = sessionHistory.subskillCounts[item.primarySubskill] ?? 0
            let balanceBonus = subskillCount < constraints.minPerSubskill ? 0.5 : 0

            let score = info - motivationPenalty + balanceBonus
            return (item, score)
        }

        return scored.max(by: { $0.1 < $1.1 })?.0
    }
}

enum SessionMode {
    case learning    // target 70% accuracy
    case assessment  // target 50% accuracy (max info)
    case review      // mixed difficulty
}

struct SessionHistory {
    var seenQuestionIDs: Set<UUID> = []
    var subskillCounts: [String: Int] = [:]
    var attempts: [Attempt] = []
}

struct ContentConstraints {
    var maxPerSubskill: Int = 10
    var minPerSubskill: Int = 2
    var maxExposure: Int = 100  // global item exposure cap
}
```

---

## 3. BKT Engine

**File**: `iga/Features/Practice/BKTEngine.swift`

```swift
actor BKTEngine {

    struct BKTParams {
        var pLearn: Double = 0.10
        var pForget: Double = 0.02
        var pGuess: Double = 0.25
        var pSlip: Double = 0.10
    }

    // Apply forgetting based on time elapsed
    func applyForgetting(pKnown: Double, daysSince: Double, pForget: Double) -> Double {
        let decay = pow(1 - pForget, daysSince)
        return pKnown * decay
    }

    // Bayesian update after observing response
    func updatePKnown(
        priorPKnown: Double,
        correct: Bool,
        params: BKTParams
    ) -> Double {
        let pObsGivenKnown = correct ? (1 - params.pSlip) : params.pSlip
        let pObsGivenUnknown = correct ? params.pGuess : (1 - params.pGuess)

        // Bayes' theorem
        let numerator = priorPKnown * pObsGivenKnown
        let denominator = numerator + (1 - priorPKnown) * pObsGivenUnknown
        let posterior = denominator > 0 ? numerator / denominator : priorPKnown

        // Apply learning transition
        let learned = posterior + (1 - posterior) * params.pLearn

        return learned
    }

    // Full mastery update
    func updateMastery(
        state: SubskillMasteryState,
        correct: Bool,
        responseTimeMs: Int,
        expectedTimeMs: Int,
        timestamp: Date
    ) -> SubskillMasteryState {
        // 1. Apply forgetting
        let daysSince = state.lastPracticed.map {
            timestamp.timeIntervalSince($0) / 86400
        } ?? 0
        let decayedPKnown = applyForgetting(
            pKnown: state.pKnown,
            daysSince: daysSince,
            pForget: state.pForget
        )

        // 2. Bayesian update
        let params = BKTParams(
            pLearn: state.pLearn,
            pForget: state.pForget,
            pGuess: 0.25,
            pSlip: 0.10
        )
        let newPKnown = updatePKnown(
            priorPKnown: decayedPKnown,
            correct: correct,
            params: params
        )

        // 3. Adjust learning rate based on response time
        var newPLearn = state.pLearn
        if correct && responseTimeMs < Int(Double(expectedTimeMs) * 0.7) {
            newPLearn = min(0.15, state.pLearn * 1.1)
        }

        // 4. Update state
        state.pKnown = newPKnown
        state.pLearn = newPLearn
        state.lastPracticed = timestamp
        state.attemptCount += 1
        if correct { state.correctCount += 1 }

        return state
    }

    // Derive mastery level from pKnown
    func masteryLevel(pKnown: Double) -> MasteryLevel {
        switch pKnown {
        case ..<0.40: return .novice
        case 0.40..<0.65: return .developing
        case 0.65..<0.85: return .proficient
        default: return .mastered
        }
    }
}
```

---

## 4. Diagnostic Flow

**Directory**: `iga/Features/Diagnostic/`

### DiagnosticEngine

```swift
actor DiagnosticEngine {
    private let irtEngine = IRTEngine()

    struct SubskillProgress {
        var attempts: [Attempt] = []
        var currentTheta: Double = 0.0
        var currentSE: Double = 1.0
        var isComplete: Bool { currentSE < 0.3 || attempts.count >= 5 }
    }

    // Select next item for diagnostic
    func selectNextItem(
        progress: [String: SubskillProgress],
        availableItems: [Question]
    ) async -> Question? {
        // Find subskill with highest uncertainty (SE) that isn't complete
        let incomplete = progress
            .filter { !$0.value.isComplete }
            .sorted { $0.value.currentSE > $1.value.currentSE }

        guard let targetSubskill = incomplete.first else { return nil }

        // Filter items for this subskill
        let subskillItems = availableItems.filter {
            $0.subskillIDs.contains(targetSubskill.key)
        }

        // Select item maximizing info at current theta
        return await irtEngine.selectNextItem(
            theta: targetSubskill.value.currentTheta,
            availableItems: subskillItems,
            sessionHistory: SessionHistory(
                seenQuestionIDs: Set(progress.values.flatMap { $0.attempts.map { $0.questionID } })
            ),
            mode: .assessment,
            constraints: ContentConstraints(maxPerSubskill: 5, minPerSubskill: 1)
        )
    }

    // Process answer and update estimates
    func processAnswer(
        progress: inout [String: SubskillProgress],
        question: Question,
        attempt: Attempt,
        allQuestions: [UUID: Question]
    ) async {
        for subskillID in question.subskillIDs {
            var subskillProgress = progress[subskillID] ?? SubskillProgress()
            subskillProgress.attempts.append(attempt)

            // Re-estimate theta for this subskill
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

    // Check if diagnostic is complete
    func isComplete(progress: [String: SubskillProgress]) -> Bool {
        let allSubskills = Subskill.allCases.map { $0.rawValue }
        return allSubskills.allSatisfy { progress[$0]?.isComplete ?? false }
    }

    // Generate final result
    func generateResult(progress: [String: SubskillProgress]) -> DiagnosticResult {
        var estimates: [String: SubskillEstimate] = [:]

        for (subskillID, subskillProgress) in progress {
            estimates[subskillID] = SubskillEstimate(
                theta: subskillProgress.currentTheta,
                standardError: subskillProgress.currentSE,
                itemCount: subskillProgress.attempts.count,
                accuracy: subskillProgress.attempts.isEmpty ? 0 :
                    Double(subskillProgress.attempts.filter { $0.isCorrect }.count) /
                    Double(subskillProgress.attempts.count)
            )
        }

        // Calculate section thetas (average of subskills)
        let quantSubskills = ["Q-AR", "Q-AL", "Q-GE", "Q-WP", "Q-DA"]
        let verbalSubskills = ["V-SE", "V-TC", "V-RC-D", "V-RC-S"]

        let quantTheta = quantSubskills.compactMap { estimates[$0]?.theta }.reduce(0, +) / 5
        let verbalTheta = verbalSubskills.compactMap { estimates[$0]?.theta }.reduce(0, +) / 4

        // Find weakest subskills
        let weakest = estimates
            .sorted { $0.value.theta < $1.value.theta }
            .prefix(3)
            .map { $0.key }

        return DiagnosticResult(
            id: UUID(),
            completedAt: Date(),
            subskillEstimates: estimates,
            overallQuantTheta: quantTheta,
            overallVerbalTheta: verbalTheta,
            recommendedFocusAreas: weakest,
            totalTimeSeconds: 0  // calculated by ViewModel
        )
    }
}
```

### DiagnosticViewModel

```swift
@Observable
final class DiagnosticViewModel {
    private let engine = DiagnosticEngine()
    private let dataStore: DataStore

    var currentQuestion: Question?
    var progress: [String: DiagnosticEngine.SubskillProgress] = [:]
    var isComplete = false
    var result: DiagnosticResult?
    var totalQuestions: Int { progress.values.reduce(0) { $0 + $1.attempts.count } }
    var startTime: Date?

    // Initialize progress for all subskills
    func startDiagnostic() async {
        startTime = Date()
        for subskill in Subskill.allCases {
            progress[subskill.rawValue] = .init()
        }
        await loadNextQuestion()
    }

    func loadNextQuestion() async {
        let items = await dataStore.fetchQuestions()
        currentQuestion = await engine.selectNextItem(progress: progress, availableItems: items)

        if currentQuestion == nil {
            await completeDiagnostic()
        }
    }

    func submitAnswer(selectedIndex: Int) async {
        guard let question = currentQuestion else { return }

        let attempt = Attempt(
            id: UUID(),
            questionID: question.id,
            sessionID: UUID(),  // diagnostic session
            selectedAnswer: selectedIndex,
            isCorrect: question.correctIndex == selectedIndex,
            responseTimeMs: 0,  // tracked by view
            hintsUsed: 0,
            timestamp: Date(),
            subskillID: question.subskillIDs.first ?? ""
        )

        let allQuestions = Dictionary(uniqueKeysWithValues:
            (await dataStore.fetchQuestions()).map { ($0.id, $0) }
        )

        await engine.processAnswer(
            progress: &progress,
            question: question,
            attempt: attempt,
            allQuestions: allQuestions
        )

        if await engine.isComplete(progress: progress) {
            await completeDiagnostic()
        } else {
            await loadNextQuestion()
        }
    }

    private func completeDiagnostic() async {
        isComplete = true
        var diagnosticResult = await engine.generateResult(progress: progress)

        if let start = startTime {
            diagnosticResult.totalTimeSeconds = Int(Date().timeIntervalSince(start))
        }

        result = diagnosticResult

        // Save to database
        // Create SubskillMasteryState for each subskill
        // Update UserProgress.diagnosticCompletedAt
    }
}
```

---

## 5. File Organization

### New Files
```
iga/
├── Data/Models/
│   ├── Subskill.swift              # NEW
│   ├── SubskillMasteryState.swift  # NEW
│   ├── Attempt.swift               # NEW
│   └── DiagnosticResult.swift      # NEW
│
├── Features/
│   ├── Practice/
│   │   ├── IRTEngine.swift         # NEW (replaces AdaptiveEngine)
│   │   └── BKTEngine.swift         # NEW
│   │
│   └── Diagnostic/                 # NEW DIRECTORY
│       ├── DiagnosticEngine.swift
│       ├── DiagnosticViewModel.swift
│       ├── DiagnosticView.swift
│       └── DiagnosticResultView.swift
│
└── Tests/FeatureTests/
    ├── IRTEngineTests.swift        # NEW
    ├── BKTEngineTests.swift        # NEW
    └── DiagnosticEngineTests.swift # NEW
```

### Modified Files
```
iga/Data/Models/Question.swift      # Add IRT params, subskills
iga/Data/Models/UserProgress.swift  # Add diagnostic fields
iga/Data/Store/DataStore.swift      # Add new model queries
iga/Features/Practice/PracticeViewModel.swift  # Use IRTEngine
iga/Features/Home/HomeView.swift    # Route to diagnostic on first launch
```

### Deleted Files
```
iga/Features/Practice/AdaptiveEngine.swift  # Replaced by IRTEngine
iga/Tests/FeatureTests/AdaptiveEngineTests.swift  # Replaced
```

---

## 6. Testing Strategy

### IRTEngineTests
- Test 3PL probability at known θ values
- Test Fisher information calculation
- Test EAP converges with repeated correct/incorrect
- Test item selection respects constraints
- Test motivational guardrails (accuracy targeting)

### BKTEngineTests
- Test forgetting decay over time
- Test Bayesian update increases pKnown on correct
- Test Bayesian update decreases pKnown on incorrect
- Test learning transition
- Test mastery level thresholds

### DiagnosticEngineTests
- Test subskill targeting (picks highest SE)
- Test termination conditions (SE < 0.3 or 5 items)
- Test result generation
- Test all subskills get coverage

---

## 7. Implementation Order

1. **Models first** - Subskill, SubskillMasteryState, Attempt, DiagnosticResult
2. **Modify Question** - Add IRT fields with defaults
3. **IRTEngine** - Core probability and selection
4. **BKTEngine** - Mastery tracking
5. **Update DataStore** - New queries
6. **DiagnosticEngine** - Ties IRT together
7. **DiagnosticViewModel + Views** - User-facing flow
8. **Update PracticeViewModel** - Use IRTEngine
9. **Wire HomeView** - Route to diagnostic
10. **Tests** - Throughout, but especially after engines
