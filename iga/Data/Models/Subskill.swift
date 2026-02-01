// IGA/Data/Models/Subskill.swift

import Foundation

// MARK: - Subskill

/// GRE subskills for granular mastery tracking
/// Based on official GRE content domains
enum Subskill: String, CaseIterable, Codable, Sendable {
    // Quantitative Reasoning
    case qArithmetic = "Q-AR"
    case qAlgebra = "Q-AL"
    case qGeometry = "Q-GE"
    case qWordProblems = "Q-WP"
    case qDataAnalysis = "Q-DA"

    // Verbal Reasoning
    case vSentenceEquiv = "V-SE"
    case vTextCompletion = "V-TC"
    case vRCDetail = "V-RC-D"
    case vRCStructure = "V-RC-S"

    /// Human-readable name
    var name: String {
        switch self {
        case .qArithmetic: return "Arithmetic & Number Properties"
        case .qAlgebra: return "Algebra & Equations"
        case .qGeometry: return "Geometry & Coordinate"
        case .qWordProblems: return "Word Problems & Applications"
        case .qDataAnalysis: return "Data Analysis & Statistics"
        case .vSentenceEquiv: return "Sentence Equivalence"
        case .vTextCompletion: return "Text Completion"
        case .vRCDetail: return "RC: Detail & Inference"
        case .vRCStructure: return "RC: Structure & Purpose"
        }
    }

    /// Short name for compact display
    var shortName: String {
        switch self {
        case .qArithmetic: return "Arithmetic"
        case .qAlgebra: return "Algebra"
        case .qGeometry: return "Geometry"
        case .qWordProblems: return "Word Problems"
        case .qDataAnalysis: return "Data Analysis"
        case .vSentenceEquiv: return "Sent. Equiv."
        case .vTextCompletion: return "Text Comp."
        case .vRCDetail: return "RC Detail"
        case .vRCStructure: return "RC Structure"
        }
    }

    /// Parent section
    var section: QuestionSection {
        switch self {
        case .qArithmetic, .qAlgebra, .qGeometry, .qWordProblems, .qDataAnalysis:
            return .quant
        case .vSentenceEquiv, .vTextCompletion, .vRCDetail, .vRCStructure:
            return .verbal
        }
    }

    /// Description of what this subskill covers
    var description: String {
        switch self {
        case .qArithmetic:
            return "Integers, fractions, decimals, percents, ratios, exponents, roots, and number properties"
        case .qAlgebra:
            return "Linear and quadratic equations, inequalities, functions, and algebraic expressions"
        case .qGeometry:
            return "Lines, angles, triangles, circles, polygons, 3D figures, and coordinate geometry"
        case .qWordProblems:
            return "Rate problems, mixture problems, work problems, and applied mathematics"
        case .qDataAnalysis:
            return "Statistics, probability, data interpretation, and quantitative comparison"
        case .vSentenceEquiv:
            return "Select two answer choices that complete the sentence with equivalent meaning"
        case .vTextCompletion:
            return "Fill in blanks to complete passages with appropriate vocabulary"
        case .vRCDetail:
            return "Identify specific details, make inferences, and understand vocabulary in context"
        case .vRCStructure:
            return "Understand passage structure, author's purpose, and rhetorical elements"
        }
    }

    /// Icon name (SF Symbols)
    var icon: String {
        switch self {
        case .qArithmetic: return "number"
        case .qAlgebra: return "x.squareroot"
        case .qGeometry: return "triangle"
        case .qWordProblems: return "text.badge.plus"
        case .qDataAnalysis: return "chart.bar"
        case .vSentenceEquiv: return "equal.circle"
        case .vTextCompletion: return "text.insert"
        case .vRCDetail: return "doc.text.magnifyingglass"
        case .vRCStructure: return "list.bullet.indent"
        }
    }

    /// Target number of items in diagnostic
    var diagnosticItemTarget: Int {
        switch self {
        case .qArithmetic, .qAlgebra, .qWordProblems, .qDataAnalysis,
             .vSentenceEquiv, .vTextCompletion:
            return 4
        case .qGeometry, .vRCDetail, .vRCStructure:
            return 3
        }
    }

    /// All quant subskills
    static var quantSubskills: [Subskill] {
        [.qArithmetic, .qAlgebra, .qGeometry, .qWordProblems, .qDataAnalysis]
    }

    /// All verbal subskills
    static var verbalSubskills: [Subskill] {
        [.vSentenceEquiv, .vTextCompletion, .vRCDetail, .vRCStructure]
    }
}

// MARK: - Mastery Level

/// Mastery levels derived from P(Known) in BKT
enum MasteryLevel: Int, Codable, Sendable, CaseIterable {
    case novice = 0      // pKnown < 0.40
    case developing = 1  // 0.40 <= pKnown < 0.65
    case proficient = 2  // 0.65 <= pKnown < 0.85
    case mastered = 3    // pKnown >= 0.85

    /// Human-readable name
    var name: String {
        switch self {
        case .novice: return "Novice"
        case .developing: return "Developing"
        case .proficient: return "Proficient"
        case .mastered: return "Mastered"
        }
    }

    /// Color name for UI
    var colorName: String {
        switch self {
        case .novice: return "red"
        case .developing: return "orange"
        case .proficient: return "blue"
        case .mastered: return "green"
        }
    }

    /// Description of what this level means
    var description: String {
        switch self {
        case .novice:
            return "Needs focused instruction and heavy practice"
        case .developing:
            return "Active learning zone - making progress"
        case .proficient:
            return "Consolidating knowledge with mixed practice"
        case .mastered:
            return "Ready for spaced review to maintain"
        }
    }

    /// Derive mastery level from pKnown
    static func from(pKnown: Double) -> MasteryLevel {
        switch pKnown {
        case ..<0.40: return .novice
        case 0.40..<0.65: return .developing
        case 0.65..<0.85: return .proficient
        default: return .mastered
        }
    }

    /// Threshold pKnown value for this level
    var threshold: Double {
        switch self {
        case .novice: return 0.0
        case .developing: return 0.40
        case .proficient: return 0.65
        case .mastered: return 0.85
        }
    }
}
