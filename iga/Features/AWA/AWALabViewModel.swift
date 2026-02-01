// IGA/Features/AWA/AWALabViewModel.swift

import Foundation
import SwiftUI

// MARK: - AWA State

enum AWAState {
    case promptSelection
    case outlining
    case writing
    case scoring
    case results
}

// MARK: - AWA Prompt

struct AWAPrompt: Identifiable {
    let id = UUID()
    let topic: String
    let fullText: String
    let category: String
    let difficulty: Int
    let keyAngles: [String]
}

// MARK: - AWA Feedback

struct AWAFeedback {
    let score: Double
    let thesisClarity: Double
    let argumentDevelopment: Double
    let evidenceQuality: Double
    let organization: Double
    let languageStyle: Double
    let grammarMechanics: Double
    let comments: [String]
    let suggestions: [String]
}

// MARK: - AWA Lab View Model

@MainActor
@Observable
final class AWALabViewModel {
    // MARK: - State

    private(set) var state: AWAState = .promptSelection
    private(set) var selectedPrompt: AWAPrompt?
    private(set) var feedback: AWAFeedback?

    // Options
    var showTimer = true
    var useOutline = true

    // Outline
    var outlinePosition = ""
    var outlineArg1 = ""
    var outlineArg2 = ""
    var outlineCounter = ""
    var outlineConclusion = ""

    // Writing
    var essayText = ""
    var showPromptInWriting = true

    // Timer
    private(set) var remainingSeconds: Int = 30 * 60  // 30 minutes
    private var timerTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let inferenceClient: InferenceClient

    // MARK: - Initialization

    init(inferenceClient: InferenceClient? = nil) {
        self.inferenceClient = inferenceClient ?? CerebrasInferenceClient.fromConfig() ?? MockInferenceClient()
    }

    // MARK: - Computed Properties

    var availablePrompts: [AWAPrompt] {
        Self.samplePrompts
    }

    var wordCount: Int {
        essayText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var formattedTimeRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    func selectPrompt(_ prompt: AWAPrompt) {
        selectedPrompt = prompt
        if useOutline {
            state = .outlining
        } else {
            startWriting()
        }
    }

    func startWriting() {
        state = .writing
        startTimer()
    }

    func skipOutline() {
        startWriting()
    }

    func submitEssay() {
        stopTimer()
        state = .scoring

        Task {
            await scoreEssay()
        }
    }

    func tryAnotherPrompt() {
        // Reset state
        selectedPrompt = nil
        essayText = ""
        outlinePosition = ""
        outlineArg1 = ""
        outlineArg2 = ""
        outlineCounter = ""
        outlineConclusion = ""
        feedback = nil
        remainingSeconds = 30 * 60
        state = .promptSelection
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    remainingSeconds -= 1
                    if remainingSeconds == 0 {
                        submitEssay()
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Scoring

    private func scoreEssay() async {
        guard let prompt = selectedPrompt else {
            state = .promptSelection
            return
        }

        do {
            let scoringPrompt = buildScoringPrompt(prompt: prompt, essay: essayText)
            let request = GenerationRequest(
                messages: [
                    ChatMessage(role: .system, content: Self.scoringSystemPrompt),
                    ChatMessage(role: .user, content: scoringPrompt)
                ],
                maxTokens: 1500,
                temperature: 0.3,
                stream: false
            )

            let response = try await inferenceClient.generate(request: request)
            feedback = parseScoreResponse(response.content)
        } catch {
            // Generate fallback feedback
            feedback = generateFallbackFeedback()
        }

        state = .results
    }

    private func buildScoringPrompt(prompt: AWAPrompt, essay: String) -> String {
        """
        Please score the following GRE Issue essay.

        PROMPT: \(prompt.fullText)

        ESSAY:
        \(essay)

        Provide your evaluation in the following JSON format:
        {
            "score": <0.0-6.0>,
            "thesisClarity": <0.0-6.0>,
            "argumentDevelopment": <0.0-6.0>,
            "evidenceQuality": <0.0-6.0>,
            "organization": <0.0-6.0>,
            "languageStyle": <0.0-6.0>,
            "grammarMechanics": <0.0-6.0>,
            "comments": ["comment1", "comment2", ...],
            "suggestions": ["suggestion1", "suggestion2", ...]
        }
        """
    }

    private func parseScoreResponse(_ response: String) -> AWAFeedback {
        // Try to extract JSON from response
        if let jsonStart = response.firstIndex(of: "{"),
           let jsonEnd = response.lastIndex(of: "}") {
            let jsonString = String(response[jsonStart...jsonEnd])
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                return AWAFeedback(
                    score: (json["score"] as? Double) ?? 3.5,
                    thesisClarity: (json["thesisClarity"] as? Double) ?? 3.5,
                    argumentDevelopment: (json["argumentDevelopment"] as? Double) ?? 3.5,
                    evidenceQuality: (json["evidenceQuality"] as? Double) ?? 3.5,
                    organization: (json["organization"] as? Double) ?? 3.5,
                    languageStyle: (json["languageStyle"] as? Double) ?? 3.5,
                    grammarMechanics: (json["grammarMechanics"] as? Double) ?? 3.5,
                    comments: (json["comments"] as? [String]) ?? ["Good effort on this essay."],
                    suggestions: (json["suggestions"] as? [String]) ?? ["Continue practicing to improve."]
                )
            }
        }

        return generateFallbackFeedback()
    }

    private func generateFallbackFeedback() -> AWAFeedback {
        // Generate basic feedback based on word count and structure
        let baseScore = min(6.0, max(1.0, Double(wordCount) / 100.0))

        return AWAFeedback(
            score: baseScore,
            thesisClarity: baseScore,
            argumentDevelopment: baseScore - 0.5,
            evidenceQuality: baseScore - 0.5,
            organization: baseScore,
            languageStyle: baseScore,
            grammarMechanics: baseScore + 0.5,
            comments: [
                "Your essay demonstrates effort in addressing the prompt.",
                "Consider developing your arguments with more specific examples."
            ],
            suggestions: [
                "Practice writing more detailed supporting paragraphs.",
                "Work on transitions between ideas.",
                "Include specific examples to strengthen your arguments."
            ]
        )
    }

    // MARK: - Static Data

    static let scoringSystemPrompt = """
    You are an expert GRE essay scorer trained on the ETS scoring rubric. Score essays on a 0-6 scale:

    6 - Outstanding: Insightful analysis, compelling reasoning, superior facility with language
    5 - Strong: Thoughtful analysis, well-developed, generally clear and well-controlled
    4 - Adequate: Competent analysis, adequate development, acceptable clarity
    3 - Limited: Some analysis but weak development, limited clarity, occasional errors
    2 - Seriously Flawed: Weak analysis, little development, frequent errors
    1 - Fundamentally Deficient: Little coherent analysis, severe problems
    0 - Off-topic or blank

    Be fair but rigorous. Most essays score 3-4. Reserve 5-6 for truly excellent work.
    Provide specific, actionable feedback referencing the essay content.
    """

    static let samplePrompts: [AWAPrompt] = [
        AWAPrompt(
            topic: "Educational institutions should actively encourage students to question and criticize authority.",
            fullText: "Educational institutions should actively encourage their students to question and criticize the ideas and decisions of authority figures, including teachers and administrators. Write a response in which you discuss the extent to which you agree or disagree with the statement and explain your reasoning for the position you take.",
            category: "Education",
            difficulty: 3,
            keyAngles: ["Critical thinking", "Respect vs. inquiry", "Academic freedom"]
        ),
        AWAPrompt(
            topic: "The best way to understand a society is to study its major cities.",
            fullText: "The best way to understand the character of a society is to examine the character of the men and women that the society chooses as its heroes or its role models. Write a response in which you discuss the extent to which you agree or disagree with the claim.",
            category: "Society & Culture",
            difficulty: 4,
            keyAngles: ["Urban representation", "Rural perspectives", "Cultural diversity"]
        ),
        AWAPrompt(
            topic: "Technology has made it easier than ever to share ideas, but it has made those ideas less meaningful.",
            fullText: "Claim: Technology has made it easier than ever before to share ideas and information. Counterclaim: However, the ease of sharing has made individual ideas less meaningful. Write a response discussing both views and your position.",
            category: "Technology",
            difficulty: 4,
            keyAngles: ["Information overload", "Quality vs. quantity", "Democratization of knowledge"]
        ),
        AWAPrompt(
            topic: "Leaders are created by the demands placed on them.",
            fullText: "Leaders are created by the demands that are placed on them. Write a response in which you discuss the extent to which you agree or disagree with the statement and explain your reasoning.",
            category: "Leadership",
            difficulty: 3,
            keyAngles: ["Nature vs. nurture", "Crisis leadership", "Training and development"]
        ),
        AWAPrompt(
            topic: "Competition is ultimately more beneficial than cooperation.",
            fullText: "Competition is ultimately more beneficial than detrimental to society. Write a response in which you discuss the extent to which you agree or disagree with the statement.",
            category: "Society",
            difficulty: 3,
            keyAngles: ["Economic competition", "Collaborative innovation", "Zero-sum thinking"]
        )
    ]
}
