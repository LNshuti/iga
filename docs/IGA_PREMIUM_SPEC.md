# IGA Premium: Comprehensive Product, Pedagogy & Technical Specification

> **Version**: 1.0
> **Date**: February 2026
> **Status**: Planning

---

## Table of Contents

1. [Product Vision and Differentiation](#1-product-vision-and-differentiation)
2. [Target Personas and Outcomes](#2-target-personas-and-outcomes)
3. [Pedagogy and Psychometrics](#3-pedagogy-and-psychometrics)
4. [Content Strategy and Editorial Pipeline](#4-content-strategy-and-editorial-pipeline)
5. [Core Feature Set (v1 Premium)](#5-core-feature-set-v1-premium)
6. [UX and Accessibility](#6-ux-and-accessibility)
7. [Technical Architecture Upgrades](#7-technical-architecture-upgrades)
8. [Algorithms and Specs](#8-algorithms-and-specs)
9. [Data Models (Examples)](#9-data-models-examples)
10. [Prompts and Guardrails](#10-prompts-and-guardrails)
11. [Analytics and Experimentation](#11-analytics-and-experimentation)
12. [Monetization and Packaging](#12-monetization-and-packaging)
13. [Roadmap (90 Days)](#13-roadmap-90-days)
14. [QA and Compliance](#14-qa-and-compliance)
15. [Examples](#15-examples)

---

## 1) Product Vision and Differentiation

### Vision

IGA is the intelligent, adaptive GRE preparation system that treats every learner as unique—combining psychometrically-rigorous assessment with AI-powered tutoring to deliver measurable score improvements in weeks, not months, through personalized mastery paths that adapt in real-time to what each student knows, struggles with, and needs to practice next.

### Differentiators vs. Competitors

| Differentiator | IGA Premium | Magoosh | Kaplan | Princeton Review | Target Test Prep |
|----------------|-------------|---------|--------|------------------|------------------|
| **True Adaptive Engine** | IRT + Bayesian knowledge tracing per subskill; real-time difficulty targeting | Static difficulty labels | Adaptive tests only | Limited adaptivity | Quant-focused adaptivity |
| **AI Socratic Tutor** | On-demand, context-aware tutoring that scaffolds without revealing answers; math-aware | Video-only | Human tutors ($$) | Limited AI | None |
| **Psychometric Rigor** | Calibrated items, confidence intervals on predicted scores, information-theoretic selection | Rough difficulty tiers | Basic scoring | Basic scoring | Strong quant metrics |
| **Mastery-Based Progression** | Subskill mastery gates with spaced mixed review; explicit forgetting models | Time-based plans | Session-based | Lesson completion | Module completion |
| **Seamless Mobile-First** | Native iOS with offline-first, Apple Pencil scratch work, VoiceOver | Web-first, basic mobile | Web + app | Web + app | Web only |

### Value Pillars Justifying $100/month

1. **Measurable Outcome Guarantee**: Diagnostic → predicted score → weekly progress → post-study delta. Refund policy if <5 point lift with ≥80% plan adherence.
2. **Elite Content Quality**: 5,000+ psychometrically-calibrated items, human-edited, free of copyright risk, with distractor rationales.
3. **Personalized Mastery Path**: Not one-size-fits-all; AI adapts daily to your gaps, pacing, and forgetting curve.
4. **On-Demand Expert Tutoring**: Unlimited Socratic AI tutoring replaces $50-100/hr human tutors for most needs.
5. **Time Efficiency**: Study 40% less time by focusing only on items that maximize learning—no wasted repetition.

---

## 2) Target Personas and Outcomes

### Persona 1: "Quant-Anxious Maya"

- **Profile**: 24, humanities BA, applying to public policy programs. Strong reader, math-avoidant since high school. Target: 315+ (V160+/Q155+).
- **Goals**: Overcome quant fear; build confidence; study around full-time job (8-10 hrs/week).
- **Constraints**: Limited budget, needs efficient study, no time for in-person classes.
- **WTP Rationale**: $100/mo for 3 months = $300, vs. $1,500+ Kaplan course or $2,000+ tutoring. Clear ROI if admits to target programs.

### Persona 2: "Verbal-Weak Raj"

- **Profile**: 27, CS MS, retaking GRE for PhD. Q168 last time, V148. ESL with academic English gaps. Target: V155+.
- **Goals**: Vocabulary depth, reading speed, sentence equivalence strategy. 6-week deadline.
- **Constraints**: Strong self-studier but needs structured vocab system and RC practice.
- **WTP Rationale**: Targeted verbal improvement worth premium; time pressure means efficiency matters more than cost.

### Persona 3: "Deadline-Driven Dana"

- **Profile**: 30, working professional, 4-week retake window. Previous: 308. Target: 318+.
- **Goals**: Rapid gap identification, intensive practice, exam stamina, no wasted time.
- **Constraints**: 15+ hrs/week available but needs maximum efficiency; already familiar with GRE format.
- **WTP Rationale**: Highest WTP—time is money; will pay premium for fastest path to target score.

### Outcome Targets

- **Primary**: +8-12 scaled points in 6-8 weeks with ≥70% plan adherence
- **Believability Mechanisms**:
  - Diagnostic establishes baseline with confidence intervals
  - Weekly mastery deltas show subskill-level progress
  - Practice test score predictions track toward target
  - Adherence metrics create accountability
  - Historical cohort data (once available) shows success rates by profile

---

## 3) Pedagogy and Psychometrics

### 3.1 Diagnostic Design

**Purpose**: Establish baseline ability estimates (θ) per subskill with minimal items to enable personalized study plan generation.

**Structure**: 30-40 items, computer-adaptive within subskills
- Quant: 18-22 items across 5 subskills
- Verbal: 12-18 items across 4 subskills

**Algorithm**:
1. Start at medium difficulty (b=0) for each subskill
2. After each response, update θ estimate via EAP
3. Select next item maximizing Fisher information for least-certain subskill
4. Terminate subskill when SE(θ) < 0.3 or 5 items administered
5. Report: θ per subskill, overall section θ, confidence bands, identified weaknesses

**Subskill Mapping**:

| Section | Subskill Code | Subskill Name | Items in Diagnostic |
|---------|---------------|---------------|---------------------|
| Quant | Q-AR | Arithmetic & Number Properties | 4 |
| Quant | Q-AL | Algebra & Equations | 4 |
| Quant | Q-GE | Geometry & Coordinate | 3 |
| Quant | Q-WP | Word Problems & Applications | 4 |
| Quant | Q-DA | Data Analysis & Statistics | 4 |
| Verbal | V-SE | Sentence Equivalence | 4 |
| Verbal | V-TC | Text Completion | 4 |
| Verbal | V-RC-D | RC: Detail & Inference | 3 |
| Verbal | V-RC-S | RC: Structure & Purpose | 3 |

### 3.2 Adaptive Engine: IRT + Bayesian Knowledge Tracing

**Upgrade from Elo**: Elo treats all items equally and doesn't model guessing or subskill decay. IRT with BKT provides:
- Item-specific discrimination (some items differentiate ability better)
- Guessing parameter for multiple-choice
- Subskill-level tracking with learning/forgetting dynamics

**IRT Model (3PL)**:
```
P(correct | θ, a, b, c) = c + (1 - c) / (1 + exp(-a(θ - b)))

where:
  θ = learner ability
  a = discrimination (0.5-2.5 typical)
  b = difficulty (-3 to +3 typical)
  c = guessing parameter (0.2 for 5-choice, 0.25 for 4-choice)
```

**Ability Estimation (EAP)**:
```
θ_EAP = ∫ θ · L(responses|θ) · π(θ) dθ / ∫ L(responses|θ) · π(θ) dθ

where:
  L(responses|θ) = Π P(r_i | θ, a_i, b_i, c_i)^r_i · (1-P)^(1-r_i)
  π(θ) = prior (from diagnostic or previous session)
```

**Item Selection (Maximum Fisher Information with Constraints)**:

```python
def select_next_item(learner, available_items, session_history):
    θ = learner.ability_estimate

    # Calculate Fisher information for each item
    candidates = []
    for item in available_items:
        if item.id in session_history.seen_ids:
            continue
        if item.exposure_count > MAX_EXPOSURE:
            continue

        # Fisher information at current θ
        p = item.probability(θ)
        q = 1 - p
        info = (item.a ** 2) * ((p - item.c) ** 2 / ((1 - item.c) ** 2)) * (q / p)

        # Content balancing penalty
        subskill_count = session_history.subskill_counts[item.subskill]
        balance_penalty = 0.1 * subskill_count

        # Motivational guardrail: penalize items too easy or too hard
        target_accuracy = 0.70 if session_history.mode == 'learning' else 0.50
        accuracy_deviation = abs(p - target_accuracy)
        motivation_penalty = 0.5 * accuracy_deviation if accuracy_deviation > 0.2 else 0

        score = info - balance_penalty - motivation_penalty
        candidates.append((item, score))

    return max(candidates, key=lambda x: x[1])[0]
```

**Mode-Specific Targeting**:
- **Learning Mode**: Target 65-75% accuracy (zone of proximal development)
- **Assessment Mode**: Target 50% accuracy (maximum information)
- **Review Mode**: Mix of mastered (80%+) and struggling (60%) items

### 3.3 Bayesian Knowledge Tracing per Subskill

```python
class SubskillMastery:
    def __init__(self, subskill_id, prior_known=0.3):
        self.p_known = prior_known  # P(L_0) from diagnostic
        self.p_learn = 0.10         # P(T) - learning rate
        self.p_forget = 0.02        # P(F) - forgetting rate
        self.p_guess = 0.25         # P(G)
        self.p_slip = 0.10          # P(S)
        self.last_practice = None

    def update(self, correct: bool, response_time: float, timestamp: datetime):
        # Apply forgetting based on time since last practice
        if self.last_practice:
            days_elapsed = (timestamp - self.last_practice).days
            self.p_known *= (1 - self.p_forget) ** days_elapsed

        # Bayesian update
        if correct:
            p_correct_given_known = 1 - self.p_slip
            p_correct_given_unknown = self.p_guess
        else:
            p_correct_given_known = self.p_slip
            p_correct_given_unknown = 1 - self.p_guess

        p_known_posterior = (
            self.p_known * p_correct_given_known /
            (self.p_known * p_correct_given_known +
             (1 - self.p_known) * p_correct_given_unknown)
        )

        # Learning transition
        self.p_known = p_known_posterior + (1 - p_known_posterior) * self.p_learn

        # Adjust learning rate based on response time (fast correct = higher learn)
        if correct and response_time < expected_time * 0.7:
            self.p_learn = min(0.15, self.p_learn * 1.1)

        self.last_practice = timestamp
```

### 3.4 Mastery Model

**Mastery Thresholds**:

| Level | P(Known) | Meaning |
|-------|----------|---------|
| Novice | < 0.40 | Needs instruction and heavy practice |
| Developing | 0.40-0.65 | Active learning zone |
| Proficient | 0.65-0.85 | Consolidation and mixed practice |
| Mastered | > 0.85 | Spaced review only |

**Promotion/Demotion Rules**:
- **Promote**: 3 consecutive correct at current level OR P(Known) > threshold for 2 sessions
- **Demote**: 2 consecutive incorrect at items below ability OR P(Known) drops below threshold
- **Mixed Review Trigger**: When ≥3 subskills reach Proficient, introduce interleaved practice mixing subskills

### 3.5 Hinting and Scaffolding Policy

**Multi-Step Hint Ladder**:
1. **Metacognitive Prompt**: "What type of problem is this? What approach might work?"
2. **Strategy Hint**: "This is a rate problem. What formula relates distance, rate, and time?"
3. **Setup Hint**: "Try setting up: distance₁ = distance₂, where distance = rate × time"
4. **Partial Solution**: "If train A travels for t hours, train B travels for (t-2) hours..."
5. **Full Walkthrough**: Complete solution with explanation (only after attempt or explicit request)

**Error-Based Feedback**:
- Detect common error patterns (sign errors, unit confusion, scope misread)
- Provide targeted correction: "I notice you might have [specific error]. Let's check..."
- Link to concept review if systematic gap detected

**Guardrails**:
- Never provide final answer before student attempts
- Require work shown for full solution access
- Track hint usage for mastery adjustment (heavy hint use = lower mastery credit)

---

## 4) Content Strategy and Editorial Pipeline

### 4.1 Question Bank Scale

**Target**: 5,000 items at launch; 6,000+ at month 6

| Section | Subtype | Target Count | Priority |
|---------|---------|--------------|----------|
| Quant | QC (Quantitative Comparison) | 800 | P0 |
| Quant | PS (Problem Solving) | 1,200 | P0 |
| Quant | Numeric Entry | 400 | P0 |
| Quant | Multiple Select | 300 | P1 |
| Verbal | SE (Sentence Equivalence) | 600 | P0 |
| Verbal | TC-1 blank | 400 | P0 |
| Verbal | TC-2 blank | 400 | P0 |
| Verbal | TC-3 blank | 200 | P1 |
| Verbal | RC-Single | 400 (100 passages × 4Q) | P0 |
| Verbal | RC-Multi | 300 (60 passages × 5Q) | P0 |

### 4.2 Item Metadata Schema

```swift
struct QuestionMetadata {
    let id: UUID
    let section: Section                    // .verbal, .quant
    let subtype: QuestionSubtype            // .qc, .ps, .se, .tc1, .rcDetail, etc.
    let subskills: [SubskillID]             // Primary + secondary subskills
    let irtParams: IRTParameters            // a, b, c values
    let difficultyTier: DifficultyTier      // .easy, .medium, .hard, .veryHard
    let timeBenchmark: TimeInterval         // Expected time in seconds (e.g., 90)
    let distractorRationales: [String: String]  // Choice ID → why wrong
    let conceptTags: [String]               // ["rate problems", "systems of equations"]
    let strategyTags: [String]              // ["backsolve", "plug in numbers"]
    let qcStatus: QCStatus                  // .draft, .reviewed, .calibrated, .published
    let calibrationData: CalibrationData?   // Pilot stats
    let version: Int
    let createdAt: Date
    let lastEditedAt: Date
    let authorID: String
    let reviewerID: String?
}

struct IRTParameters: Codable {
    var a: Double = 1.0      // Discrimination: 0.5-2.5
    var b: Double = 0.0      // Difficulty: -3 to +3
    var c: Double = 0.2      // Guessing: ~1/choices
    var se_a: Double?        // Standard error
    var se_b: Double?
    var calibrationN: Int = 0
}
```

### 4.3 AWA Content

**Scale**: 200+ Issue prompts

**Structure per Prompt**:
- Prompt text (ETS-style issue statement)
- Position spectrum (what stances are defensible)
- Key considerations/angles
- 5 exemplar essays (scores 1-2, 3, 4, 5, 6) with annotations
- Common pitfalls for this prompt
- Suggested evidence categories

### 4.4 Vocabulary Content

**Scale**: 2,500 words at launch; 3,500 target

**Per-Word Data**:

```swift
struct VocabWord {
    let word: String
    let partOfSpeech: PartOfSpeech
    let definitions: [Definition]           // With usage contexts
    let roots: [WordRoot]                   // Etymology
    let synonyms: [SynonymEntry]            // With nuance notes
    let antonyms: [String]
    let collocations: [String]              // "abject poverty", "abject failure"
    let exampleSentences: [ExampleSentence] // Academic register
    let audioURL: URL?                      // Pronunciation
    let mnemonicImage: URL?                 // Visual memory aid
    let mnemonicText: String?               // Memory hook
    let greFrequency: FrequencyTier         // .core, .common, .advanced
    let difficultyRating: Double            // 1-10
    let semanticEmbedding: [Float]?         // For similarity search
}
```

### 4.5 Content Operations Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTENT PIPELINE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌────────┐ │
│  │  LLM     │───▶│  Auto    │───▶│  Human   │───▶│  Pilot   │───▶│Publish │ │
│  │  Draft   │    │  Valid   │    │  Edit    │    │  Calib   │    │        │ │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘    └────────┘ │
│       │              │                │               │              │       │
│       ▼              ▼                ▼               ▼              ▼       │
│   Prompt +       Style Check      Expert QA       50-100         Release    │
│   Constraints    Dedup (embed)    Accuracy        responses      to prod    │
│   Difficulty     Bias Screen      Clarity         Fit IRT        Version    │
│   targeting      Plagiarism       Pedagogy        params         control    │
│                  Math verify                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Roles:
- Content Engineer: Prompt design, validator maintenance, pipeline ops
- Subject Expert (Quant): Math accuracy, pedagogy, difficulty calibration
- Subject Expert (Verbal): Passage selection, vocab, linguistic accuracy
- QA Lead: Final review, psychometric analysis, release approval

SLAs:
- Draft → Auto-validated: < 1 minute
- Auto-validated → Human edit: < 24 hours
- Human edit → Pilot ready: < 48 hours
- Pilot → Calibrated: 7-14 days (accumulate responses)
- Calibrated → Published: < 24 hours after approval
```

**Automated Validators**:
1. **Style Conformity**: Check question structure matches GRE format
2. **Deduplication**: Embedding similarity < 0.85 to existing items
3. **Bias Screening**: Flag demographic, cultural, or stereotype issues
4. **Math Verification**: Symbolic solver confirms answer correctness (Quant)
5. **Plagiarism**: Cross-reference against known test prep content
6. **Reading Level**: Flesch-Kincaid for RC passages (target: graduate level)

---

## 5) Core Feature Set (v1 Premium)

### 5.1 Exam Mode

**Purpose**: Authentic test simulation for stamina training and score prediction.

**Features**:
- **Authentic Interface**: Matches GRE screen layout—question pane, answer choices, navigation bar, timer
- **Section Timing**: Enforced per-section timers (Verbal: 18 min × 2, Quant: 21 min × 2)
- **Question Types**: All official types including numeric entry with validation, multi-select with "indicate all that apply"
- **On-Screen Calculator**: Basic calculator for Quant (matches TI-30X style constraints)
- **Review Flags**: Mark questions for review, navigate freely within section
- **No Hints**: Tutor disabled; pure assessment conditions
- **Stamina Simulation**: Full-length option (2+ hours) with optional break timing
- **Lockdown Mode**: Notifications suppressed, no app switching (warns if violated)

**Post-Test Analytics**:
- Estimated scaled score per section (130-170) with 90% CI
- Time analysis: avg time per question type, flagged slow/fast items
- Accuracy by subskill and difficulty
- Comparison to previous practice tests
- Recommended focus areas

### 5.2 Adaptive Practice

**Study Blocks**: 15-30 minute focused sessions on weak subskills

**Dynamic Difficulty**: IRT-driven item selection maintaining ZPD

**Error Log**:
- Persistent mistake journal
- Categorized by error type (conceptual, careless, time pressure)
- Linked to explanations and similar practice items

**Deliberate Practice Drills**:
- Subskill-specific sets (e.g., "20 rate problems")
- Strategy-focused drills (e.g., "backsolving practice")
- Timed mini-sections for pacing

**Warm-up/Cool-down**:
- Pre-session: 3-5 review items from past mistakes
- Post-session: 2-3 items from newly learned concepts for consolidation

### 5.3 Tutor Chat+

**Core Interaction**: Socratic dialogue that guides without revealing

**Math Rendering**: LaTeX support with proper fraction, exponent, radical display

**Step Checking**: User enters work; AI verifies each step, catches errors early

**Tools**:
- **Calculator Function**: Natural language ("what's 15% of 340?") → computed result
- **Whiteboard**: Scratch space with undo (iPad: Pencil support)
- **Diagram Helper**: "Draw a right triangle with legs 3 and 4" → generated visual

**Explain My Error**: User shares their work/answer; AI diagnoses the specific mistake

**Guardrails**:
```
SYSTEM PROMPT (excerpt):
You are a Socratic tutor helping with GRE prep. NEVER:
- Provide the final answer before the student attempts
- Give real GRE questions (refer to "similar to what ETS might ask")
- Encourage shortcuts that won't work on test day

ALWAYS:
- Ask clarifying questions about the student's thinking
- Provide hints in escalating specificity (concept → strategy → setup → partial)
- Celebrate effort and progress, not just correct answers
- End explanations with "Does this make sense?" or "What would you try next?"
```

**Drill Linking**: After explanation, offer: "Want to try a similar problem to practice this?"

### 5.4 AWA Lab

**Timed Writing**: 30-minute countdown with pause option (noted in logs)

**Word Count**: Live counter with soft targets (300-500 words recommended)

**Outline Assistant**: Optional structured brainstorm before writing:
- Position statement
- 2-3 main supporting points
- Potential counterargument
- Conclusion angle

**AI Scoring**:
- Score 1-6 aligned to ETS rubric
- Evidence-based feedback:
  - Thesis clarity
  - Argument development
  - Evidence quality/specificity
  - Organization and transitions
  - Language/vocabulary sophistication
  - Grammar and mechanics
- Specific quotes from essay with improvement suggestions
- Comparison to exemplar at same score level

**Revision Cycles**: Edit mode with tracked changes; re-score to see improvement

### 5.5 Reading Comprehension Suite

**Passage Display**:
- Highlighting with color coding (main idea, evidence, transitions)
- Line numbers for reference
- Collapsible/expandable for longer passages
- Note-taking margin

**Question Stems Taxonomy**:
- Main Idea / Primary Purpose
- Detail / Specific Information
- Inference / Implication
- Vocabulary in Context
- Author's Tone / Attitude
- Logical Structure / Function
- Strengthen / Weaken

**Strategy Tips**: Per-question-type guidance on elimination, scope analysis, evidence requirements

**Micro-Drills**: Timed single-passage sets (5-7 minutes target)

### 5.6 Vocabulary Studio

**SRS Engine**: SM-2+ with difficulty adaptation (see Section 8)

**Practice Modes**:

| Mode | Description |
|------|-------------|
| Definition | See word → recognize definition |
| Reverse | See definition → recall word |
| Cloze | Fill blank in sentence |
| Synonym | Match word to synonym pair |
| Antonym | Identify opposite |
| Image Recall | Mnemonic image → recall word |
| Typing | Spell the word correctly |

**Root Families**: Group words by shared roots (e.g., "-dict-" → predict, contradict, dictate)

**Mixed Reviews**: Interleaved practice across modes and word sets

**Semantic Neighborhoods**: "Words similar to 'ephemeral'" via embedding similarity

**Personal Wordbook**: Import custom words from reading; auto-lookup definitions

### 5.7 Study Plans

**Diagnostic-Driven Generation**:
```
Input: Diagnostic results, target score, available hours/week, test date
Output: Week-by-week plan with daily tasks

Example Week Plan:
- Monday: Quant Algebra drill (30 min), Vocab review (15 min)
- Tuesday: RC passage practice (25 min), Tutor session for Q-WP weak area (20 min)
- Wednesday: Rest or light vocab
- Thursday: Mixed Quant practice (30 min), AWA outline practice (15 min)
- Friday: Full Verbal section timed (25 min)
- Saturday: Practice test (2 hrs) OR intensive weak-area focus
- Sunday: Review mistakes, plan adjustment
```

**Dynamic Rescheduling**: Missed sessions get redistributed; priorities auto-adjust

**Calendar Integration**: Export to iOS Calendar; smart reminders based on study patterns

**Streaks & Rewards**: Daily streak tracking; milestone badges; progress celebrations

### 5.8 Progress & Analytics

**Mastery Dashboard**:
- Visual subskill mastery grid (color-coded)
- Trend lines per subskill over time
- "At risk" indicators for skills showing decay

**Pacing Metrics**:
- Avg time vs. benchmark per question type
- Speed/accuracy tradeoff visualization
- Improvement trajectory

**Predicted Score**:
- Current estimated range with confidence bands
- "If you maintain this trajectory" projection
- Gap to target score with estimated time to close

**Weekly Summary** (push notification + email option):
- Hours studied
- Questions completed
- Mastery gains
- Words learned
- Predicted score movement
- Next week focus areas

---

## 6) UX and Accessibility

### 6.1 iOS-Native Design

**Design Principles**:
- Follow Human Interface Guidelines
- SF Symbols for iconography
- Native navigation patterns (tab bar, navigation stack)
- System colors that respect Dark Mode

**Dynamic Type**: All text scales from xSmall to AX5 accessibility sizes

**VoiceOver**:
- All interactive elements labeled
- Math content has spoken descriptions ("fraction: 3 over 4")
- Custom rotor actions for question navigation

**Contrast**: WCAG AA minimum (4.5:1 text, 3:1 UI components)

**Haptics**: Confirmation feedback on answer submission, achievement unlocks

**Accessible Math**: MathML backing with spoken descriptions; pinch-to-zoom on equations

**One-Handed Mode**: Bottom-anchored primary actions; reachability considerations

### 6.2 iPad Layouts

- Sidebar navigation for quick switching
- Split view: passage + questions for RC
- Pencil scratch work area with palm rejection
- Larger touch targets optimized for tablet

### 6.3 Session Flow Templates

**Exam Mode Flow**:
```
Start → Instructions → Section 1 → (optional break) → Section 2 → ... → Review → Submit → Results
```

**Practice Flow**:
```
Home → Select Practice Type → Configure (subskill, duration) → Session →
Per-Question: Present → Answer → Immediate Feedback → [Optional: Tutor Help] → Next
→ Session Summary → Offer: Review Mistakes / Continue / Exit
```

**Vocab Flow**:
```
Vocab Home → Today's Review (due cards) → Learn New (if review complete) →
Card: Front → [Flip/Answer] → Self-Grade or Auto-Grade → Next
→ Session Complete → Stats
```

**AWA Flow**:
```
AWA Home → Select Practice Type → Choose Prompt → (Optional: Outline) →
Timed Writing → Submit → AI Scoring → Review Feedback → (Optional: Revise)
```

---

## 7) Technical Architecture Upgrades

### 7.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PRESENTATION LAYER                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │  Home    │ │ Practice │ │  Tutor   │ │  Vocab   │ │ Analytics│          │
│  │  View    │ │  Views   │ │  Chat    │ │  Views   │ │  Views   │          │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘          │
│       │            │            │            │            │                 │
│  ┌────┴────────────┴────────────┴────────────┴────────────┴────┐           │
│  │                     @Observable ViewModels                    │           │
│  │  HomeVM │ PracticeVM │ ExamVM │ TutorVM │ VocabVM │ PlanVM   │           │
│  └────────────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
┌─────────────────────────────────────────────────────────────────────────────┐
│                               DOMAIN LAYER                                   │
│  ┌────────────────────────────────────────────────────────────────┐         │
│  │                         USE CASES                               │         │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │         │
│  │  │ Diagnostic  │ │  Adaptive   │ │   Mastery   │ │  Study    │ │         │
│  │  │ UseCase     │ │  Practice   │ │   Tracker   │ │  Planner  │ │         │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │         │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │         │
│  │  │    AWA      │ │    SRS      │ │   Scoring   │ │  Tutor    │ │         │
│  │  │  Feedback   │ │   Engine    │ │   Engine    │ │   Logic   │ │         │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │         │
│  └────────────────────────────────────────────────────────────────┘         │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────┐         │
│  │                    DOMAIN MODELS (Pure Swift)                   │         │
│  │  Question │ Passage │ IRTParams │ Subskill │ MasteryState │ ... │        │
│  └────────────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
┌─────────────────────────────────────────────────────────────────────────────┐
│                                DATA LAYER                                    │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐                │
│  │   SwiftData     │ │   CloudKit      │ │   AI Client     │                │
│  │   Repository    │ │   Sync          │ │   (Cerebras)    │                │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐                │
│  │  Vector Store   │ │   Content       │ │   Analytics     │                │
│  │  (Embeddings)   │ │   Loader        │ │   Telemetry     │                │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Expanded SwiftData Models

```swift
// Core Question Model
@Model
final class Question {
    @Attribute(.unique) var id: UUID
    var section: String              // "verbal" | "quant"
    var subtype: String              // "qc", "ps", "se", "tc1", etc.
    var stem: String                 // Question text (may include LaTeX)
    var choices: [Choice]            // For MC questions
    var correctAnswer: String        // Choice ID or numeric value
    var passage: Passage?            // For RC questions
    var subskills: [String]          // Subskill IDs
    var irtParams: IRTParamsData
    var difficultyTier: Int          // 1-4
    var timeBenchmarkSeconds: Int
    var explanation: String
    var distractorRationales: [String: String]
    var conceptTags: [String]
    var strategyTags: [String]
    var version: Int

    init(...) { ... }
}

@Model
final class Passage {
    @Attribute(.unique) var id: UUID
    var text: String
    var sourceDescription: String    // Genre/topic hint
    var wordCount: Int
    var questions: [Question]
}

@Model
final class Attempt {
    @Attribute(.unique) var id: UUID
    var questionID: UUID
    var userID: UUID
    var sessionID: UUID
    var selectedAnswer: String?
    var isCorrect: Bool
    var responseTimeMs: Int
    var hintsUsed: Int
    var timestamp: Date
    var abilityEstimateBefore: Double?
    var abilityEstimateAfter: Double?
}

@Model
final class SubskillMasteryState {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var subskillID: String
    var pKnown: Double               // Current P(L)
    var pLearn: Double               // Current learning rate
    var pForget: Double              // Current forgetting rate
    var attemptCount: Int
    var correctCount: Int
    var lastPracticed: Date?
    var masteryLevel: Int            // 0=novice, 1=developing, 2=proficient, 3=mastered
    var thetaEstimate: Double        // IRT ability for this subskill
    var thetaSE: Double              // Standard error
}

@Model
final class StudyPlan {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var targetScore: Int
    var testDate: Date?
    var weeklyHours: Int
    var createdAt: Date
    var tasks: [StudyTask]
    var isActive: Bool
}

@Model
final class StudyTask {
    @Attribute(.unique) var id: UUID
    var planID: UUID
    var dayOfWeek: Int               // 1-7
    var weekNumber: Int
    var taskType: String             // "practice", "vocab", "awa", "test", "review"
    var subskillFocus: String?
    var durationMinutes: Int
    var isCompleted: Bool
    var completedAt: Date?
    var rescheduledFrom: Date?
}

@Model
final class Flashcard {
    @Attribute(.unique) var id: UUID
    var wordID: UUID
    var userID: UUID
    var easeFactor: Double           // SM-2 EF (default 2.5)
    var interval: Int                // Days until next review
    var repetitions: Int             // Consecutive correct
    var nextReviewDate: Date
    var lastReviewDate: Date?
    var lapseCount: Int              // Times forgotten
}

@Model
final class Essay {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var promptID: UUID
    var content: String
    var wordCount: Int
    var writingTimeSeconds: Int
    var submittedAt: Date
    var feedback: EssayFeedback?
    var revisionOf: UUID?            // Links to previous version
}

@Model
final class EssayFeedback {
    @Attribute(.unique) var id: UUID
    var essayID: UUID
    var overallScore: Int            // 1-6
    var thesisScore: Int
    var developmentScore: Int
    var organizationScore: Int
    var languageScore: Int
    var mechanicsScore: Int
    var strengths: [String]
    var improvements: [String]
    var specificComments: [EssayComment]
    var generatedAt: Date
}
```

### 7.3 CloudKit Sync Strategy

**Sync Scope**:
- User profile and preferences
- Attempt history
- Mastery states
- Study plan and progress
- Flashcard states
- Essays and feedback

**NOT Synced** (downloaded from server):
- Question bank (bundled + delta updates)
- Vocabulary database
- AWA prompts

**Conflict Resolution**:

```swift
enum ConflictResolution {
    case serverWins      // For attempt records (chronological)
    case clientWins      // For user preferences
    case merge           // For mastery states (take max practice count, recalculate)
    case manual          // For essays (prompt user)
}
```

**Offline-First Pattern**:
1. All writes go to local SwiftData immediately
2. Sync queue tracks pending changes
3. Background sync when network available
4. Telemetry events queued with timestamps

### 7.4 AI Client Enhancements

```swift
protocol InferenceClient {
    // Existing
    func chatCompletion(messages: [Message], config: ChatConfig) async throws -> ChatResponse
    func streamCompletion(messages: [Message], config: ChatConfig) -> AsyncThrowingStream<String, Error>
    func embeddings(texts: [String]) async throws -> [[Float]]

    // New Tools
    func chatWithTools(
        messages: [Message],
        tools: [Tool],
        config: ChatConfig
    ) async throws -> ToolCallResponse
}

enum Tool {
    case mathEvaluator      // Evaluate mathematical expressions
    case rubricScorer       // Score against defined rubric
    case promptRouter       // Route to specialized prompt
    case similaritySearch   // Find similar content
}

struct ToolCallResponse {
    let content: String?
    let toolCalls: [ToolCall]
}
```

**Safety & Determinism**:
- System prompts versioned and tested
- Temperature = 0 for scoring tasks
- Response validators check:
  - Math answers match symbolic solution
  - Scores within valid range
  - No prohibited content patterns

### 7.5 Local Vector Store

```swift
class LocalVectorStore {
    private var index: SimilarityIndex  // HNSW or brute-force for small sets
    private let embeddingCache: NSCache<NSString, EmbeddingVector>

    func add(id: String, embedding: [Float], metadata: [String: Any])
    func search(query: [Float], k: Int, filter: Filter?) -> [SearchResult]
    func batchSearch(queries: [[Float]], k: Int) -> [[SearchResult]]

    // Pre-computed embeddings loaded from bundle
    func loadPrecomputedIndex(from url: URL) async throws
}
```

**Use Cases**:
- Question similarity (find related practice items)
- Vocabulary neighborhoods (semantic word groups)
- Passage topic matching

### 7.6 Performance Optimizations

**Token Streaming**: Display AI responses incrementally

```swift
func streamTutorResponse(to binding: Binding<String>) async {
    for try await chunk in client.streamCompletion(messages: history) {
        await MainActor.run {
            binding.wrappedValue += chunk
        }
    }
}
```

**Request Coalescing**: Batch embedding requests

```swift
actor EmbeddingBatcher {
    private var pending: [(String, CheckedContinuation<[Float], Error>)] = []
    private var flushTask: Task<Void, Never>?

    func embed(_ text: String) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            pending.append((text, continuation))
            scheduleFlush()
        }
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task {
            try? await Task.sleep(for: .milliseconds(50))
            await flush()
        }
    }
}
```

**Background Prefetch**: Predict next likely questions and pre-load

**Content Sharding**: Question bank split into downloadable chunks by section/difficulty

**Memory-Safe Math Rendering**: Lazy load complex LaTeX; cap render complexity

### 7.7 Security & Privacy

**PII Minimization**:
- No names required; anonymous user IDs
- Essay content encrypted at rest
- Chat history pruned after 30 days (summary retained)

**Encryption**:
- SwiftData encryption via Data Protection
- CloudKit encrypted at rest
- HTTPS only for all network

**Exam Integrity**:
- Detect app backgrounding during exam
- Screenshot detection (log, don't prevent)
- No copy/paste in exam mode
- Timestamp validation on submissions

**Analytics Opt-In**:
- Clear consent UI
- Granular controls (performance only vs. full telemetry)
- Data export capability (GDPR Article 20)

---

## 8) Algorithms and Specs

### 8.1 IRT Implementation

**Ability Estimation (EAP with Gaussian Prior)**:

```
θ_EAP = Σ(θ_k · L(R|θ_k) · π(θ_k)) / Σ(L(R|θ_k) · π(θ_k))

where:
- θ_k are quadrature points from -4 to +4
- L(R|θ) = Π P_i(θ)^r_i · (1-P_i(θ))^(1-r_i)  for all items
- π(θ) = N(μ_prior, σ_prior)  -- from diagnostic or previous session
- P_i(θ) = c_i + (1-c_i) / (1 + exp(-a_i(θ - b_i)))  -- 3PL
```

**Standard Error**:
```
SE(θ) = 1 / √(Σ I_i(θ))

where I_i(θ) = Fisher information at θ for item i
I_i(θ) = a_i² · ((P_i - c_i)/(1 - c_i))² · ((1-P_i)/P_i)
```

**Item Selection Pseudocode**:

```python
def select_item_max_info_constrained(
    theta: float,
    available_items: List[Item],
    session: Session,
    content_constraints: ContentConstraints
) -> Item:
    """
    Select item maximizing Fisher information with constraints.
    """
    best_item = None
    best_score = -inf

    for item in available_items:
        # Skip if already seen or over-exposed
        if item.id in session.seen_items:
            continue
        if item.exposure_count >= content_constraints.max_exposure:
            continue

        # Content balancing: enforce min/max per subskill
        subskill_count = session.subskill_counts.get(item.subskill, 0)
        if subskill_count >= content_constraints.max_per_subskill:
            continue

        # Calculate Fisher information
        p = item.prob_correct(theta)
        q = 1 - p
        if p <= item.c or p >= 1:
            info = 0
        else:
            info = (item.a ** 2) * ((p - item.c) ** 2 / ((1 - item.c) ** 2)) * (q / p)

        # Apply constraints as penalties
        score = info

        # Subskill underrepresentation bonus
        if subskill_count < content_constraints.min_per_subskill:
            score += 0.5

        # Motivational guardrail (learning mode)
        if session.mode == 'learning':
            target_p = 0.70
            deviation = abs(p - target_p)
            if deviation > 0.15:
                score -= deviation * 2

        # Exposure control (prefer less-seen items)
        score -= 0.01 * item.exposure_count

        if score > best_score:
            best_score = score
            best_item = item

    return best_item
```

### 8.2 Bayesian Knowledge Tracing

**Update Equations**:

```python
def bkt_update(prior_known: float, correct: bool, params: BKTParams) -> float:
    """
    Update P(Known) based on observation.

    params:
        p_learn: P(T) - probability of learning
        p_forget: P(F) - probability of forgetting
        p_guess: P(G) - probability of guessing correctly
        p_slip: P(S) - probability of slipping (error despite knowing)
    """
    p_guess = params.p_guess
    p_slip = params.p_slip
    p_learn = params.p_learn

    # P(correct | known) and P(correct | not known)
    if correct:
        p_obs_given_known = 1 - p_slip
        p_obs_given_unknown = p_guess
    else:
        p_obs_given_known = p_slip
        p_obs_given_unknown = 1 - p_guess

    # Posterior P(known | observation) via Bayes
    numerator = prior_known * p_obs_given_known
    denominator = numerator + (1 - prior_known) * p_obs_given_unknown
    p_known_posterior = numerator / denominator

    # Apply learning transition
    p_known_updated = p_known_posterior + (1 - p_known_posterior) * p_learn

    return p_known_updated

def apply_forgetting(p_known: float, days_elapsed: int, p_forget: float) -> float:
    """
    Apply forgetting decay based on time since last practice.
    """
    decay = (1 - p_forget) ** days_elapsed
    return p_known * decay
```

### 8.3 SM-2+ for Vocabulary

```python
class SM2Plus:
    """
    Enhanced SM-2 with response time adaptation.
    """

    def __init__(self):
        self.min_ef = 1.3
        self.initial_ef = 2.5
        self.initial_interval = 1

    def review(
        self,
        card: Flashcard,
        quality: int,          # 0-5 scale
        response_time_ms: int,
        expected_time_ms: int
    ) -> Flashcard:
        """
        Update flashcard after review.

        quality:
            5 - perfect response
            4 - correct after hesitation
            3 - correct with difficulty
            2 - incorrect, but remembered upon seeing answer
            1 - incorrect, remembered vaguely
            0 - complete blackout
        """
        # Time factor: fast correct = boost, slow = slight penalty
        time_ratio = response_time_ms / expected_time_ms
        time_modifier = 1.0
        if quality >= 3:  # Correct
            if time_ratio < 0.5:
                time_modifier = 1.1  # Fast = boost
            elif time_ratio > 2.0:
                time_modifier = 0.95  # Slow = slight penalty

        # Update ease factor
        new_ef = card.ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
        new_ef = max(self.min_ef, new_ef * time_modifier)

        # Determine new interval
        if quality < 3:
            # Failed: reset but retain some progress
            new_interval = 1
            new_repetitions = 0
            card.lapse_count += 1
        else:
            new_repetitions = card.repetitions + 1
            if new_repetitions == 1:
                new_interval = 1
            elif new_repetitions == 2:
                new_interval = 6
            else:
                new_interval = int(card.interval * new_ef)

        # Apply word difficulty modifier
        difficulty_mod = 0.8 + (card.word_difficulty / 10) * 0.4  # 0.8x to 1.2x
        new_interval = int(new_interval * difficulty_mod)

        # Cap interval
        new_interval = min(new_interval, 365)

        return Flashcard(
            ...card,
            ease_factor=new_ef,
            interval=new_interval,
            repetitions=new_repetitions,
            next_review_date=today() + days(new_interval)
        )
```

### 8.4 Score Estimation

```python
def estimate_scaled_score(theta: float, section: str) -> ScoreEstimate:
    """
    Convert IRT theta to GRE scaled score (130-170).

    Uses empirically-calibrated lookup table from pilot data.
    """
    # Lookup table: theta → scaled score (linear interpolation between points)
    # Calibrated from pilot test equating
    THETA_TO_SCORE = {
        'verbal': [
            (-3.0, 130), (-2.0, 138), (-1.0, 147), (0.0, 153),
            (1.0, 159), (2.0, 164), (3.0, 170)
        ],
        'quant': [
            (-3.0, 130), (-2.0, 140), (-1.0, 148), (0.0, 155),
            (1.0, 161), (2.0, 166), (3.0, 170)
        ]
    }

    points = THETA_TO_SCORE[section]
    scaled = interpolate(theta, points)
    scaled = clamp(scaled, 130, 170)

    # Confidence interval based on SE(theta)
    # Approximate: ±1 SE → ±3-5 scaled points
    se_scaled = max(2, int(theta_se * 4))

    return ScoreEstimate(
        point=round(scaled),
        lower=max(130, round(scaled - se_scaled)),
        upper=min(170, round(scaled + se_scaled)),
        confidence=0.90
    )
```

---

## 9) Data Models (Examples)

### 9.1 Question with Full Metadata

```json
{
  "id": "q-quant-001-abc123",
  "section": "quant",
  "subtype": "qc",
  "stem": "Quantity A: $\\frac{x^2 - 4}{x - 2}$ when $x > 2$\n\nQuantity B: $x + 2$",
  "choices": [
    {"id": "A", "text": "Quantity A is greater."},
    {"id": "B", "text": "Quantity B is greater."},
    {"id": "C", "text": "The two quantities are equal."},
    {"id": "D", "text": "The relationship cannot be determined from the information given."}
  ],
  "correctAnswer": "C",
  "passage": null,
  "subskills": ["Q-AL"],
  "irtParams": {
    "a": 1.2,
    "b": -0.5,
    "c": 0.25,
    "se_a": 0.15,
    "se_b": 0.12,
    "calibrationN": 847
  },
  "difficultyTier": 2,
  "timeBenchmarkSeconds": 90,
  "explanation": "Factor the numerator: $x^2 - 4 = (x-2)(x+2)$. For $x > 2$, we can simplify $\\frac{(x-2)(x+2)}{x-2} = x + 2$. Both quantities equal $x + 2$, so they are always equal when $x > 2$.",
  "distractorRationales": {
    "A": "Might result from not simplifying or thinking the fraction is always larger",
    "B": "Might result from sign error in factoring",
    "D": "Trap for those who don't recognize the simplification is always valid for x > 2"
  },
  "conceptTags": ["factoring", "difference of squares", "algebraic simplification"],
  "strategyTags": ["simplify first", "recognize special forms"],
  "qcStatus": "published",
  "version": 2,
  "authorID": "content-eng-01",
  "reviewerID": "quant-expert-03"
}
```

### 9.2 Attempt Record

```swift
struct AttemptRecord: Codable {
    let id: UUID
    let questionID: UUID
    let userID: UUID
    let sessionID: UUID
    let sessionType: String          // "diagnostic", "practice", "exam"
    let selectedAnswer: String?       // "C" or "42.5" for numeric
    let isCorrect: Bool
    let responseTimeMs: Int
    let hintsUsed: Int
    let hintLevels: [Int]            // [1, 2] = used hints 1 and 2
    let flaggedForReview: Bool
    let timestamp: Date
    let abilityBefore: Double?
    let abilityAfter: Double?
    let masteryBefore: Double?       // P(Known) for primary subskill
    let masteryAfter: Double?
}
```

### 9.3 Mastery State

```swift
struct MasteryStateSnapshot: Codable {
    let userID: UUID
    let subskillID: String           // "Q-AL"
    let subskillName: String         // "Algebra & Equations"
    let section: String              // "quant"

    // BKT state
    let pKnown: Double               // 0.72
    let pLearn: Double               // 0.12
    let pForget: Double              // 0.02

    // IRT state
    let thetaEstimate: Double        // 0.8
    let thetaSE: Double              // 0.25

    // Aggregate stats
    let totalAttempts: Int           // 47
    let correctCount: Int            // 34
    let recentAccuracy: Double       // Last 10: 0.80
    let avgResponseTimeMs: Int       // 85000

    // Temporal
    let lastPracticed: Date
    let daysSinceLastPractice: Int
    let practiceStreak: Int          // Consecutive days

    // Derived
    let masteryLevel: MasteryLevel   // .proficient
    let forgettingRisk: ForgettingRisk  // .low
    let recommendedAction: String    // "Ready for mixed review"
}

enum MasteryLevel: String, Codable {
    case novice      // pKnown < 0.40
    case developing  // 0.40 <= pKnown < 0.65
    case proficient  // 0.65 <= pKnown < 0.85
    case mastered    // pKnown >= 0.85
}
```

### 9.4 Flashcard State

```swift
struct FlashcardState: Codable {
    let id: UUID
    let wordID: UUID
    let word: String                 // "Ephemeral"
    let userID: UUID

    // SM-2+ state
    let easeFactor: Double           // 2.3
    let interval: Int                // 12 days
    let repetitions: Int             // 4
    let lapseCount: Int              // 1

    // Scheduling
    let nextReviewDate: Date
    let lastReviewDate: Date
    let isDue: Bool
    let overdueDays: Int             // 0 if not due, positive if overdue

    // Performance history
    let reviewHistory: [ReviewEntry]
    let averageQuality: Double       // 3.8
    let averageResponseTimeMs: Int   // 4200

    // Word metadata (denormalized for performance)
    let wordDifficulty: Double       // 6.5 / 10
    let frequencyTier: String        // "common"
}

struct ReviewEntry: Codable {
    let date: Date
    let quality: Int                 // 0-5
    let responseTimeMs: Int
    let mode: String                 // "definition", "cloze", etc.
}
```

### 9.5 Essay Feedback

```swift
struct EssayFeedbackData: Codable {
    let id: UUID
    let essayID: UUID
    let promptID: UUID
    let promptText: String

    // Scores (1-6 scale aligned to ETS rubric)
    let overallScore: Int            // 4
    let criteriaScores: CriteriaScores

    // Qualitative feedback
    let strengths: [String]
    let areasForImprovement: [String]
    let specificComments: [SpecificComment]

    // Exemplar comparison
    let nearestExemplarScore: Int    // 4
    let comparisonNotes: String

    // Actionable next steps
    let revisionSuggestions: [String]
    let practiceRecommendations: [String]

    let generatedAt: Date
    let modelVersion: String
}

struct CriteriaScores: Codable {
    let thesisClarity: Int           // 4
    let argumentDevelopment: Int     // 3
    let evidenceQuality: Int         // 4
    let organizationFlow: Int        // 5
    let languageSophistication: Int  // 4
    let grammarMechanics: Int        // 5
}

struct SpecificComment: Codable {
    let paragraphIndex: Int          // 2
    let highlightedText: String      // "While some may argue..."
    let comment: String              // "Strong counterargument acknowledgment. Consider developing this further."
    let type: CommentType            // .strength or .improvement
}
```

---

## 10) Prompts and Guardrails

### 10.1 Tutor Chat System Prompt

```
ROLE: You are a Socratic GRE tutor. Your goal is to help students understand concepts deeply, not just get answers.

CORE PRINCIPLES:
1. NEVER provide the final answer until the student has genuinely attempted the problem
2. Guide through questions, not statements
3. Catch and address misconceptions with targeted follow-ups
4. Celebrate effort and progress
5. Be encouraging but honest about mistakes

HINT LADDER (escalate only when needed):
Level 1 - Metacognitive: "What type of problem is this?" "What approach might work here?"
Level 2 - Strategy: "This is a [type] problem. The key relationship is..."
Level 3 - Setup: "Let's set up the equation: [partial setup]. What comes next?"
Level 4 - Partial: "So far we have [steps]. The next step would be to..."
Level 5 - Full (only after attempt): Complete walkthrough with explanation

MATH FORMATTING:
- Use LaTeX for all mathematical expressions: $x^2 + y^2$
- Use display mode for multi-step work: $$\frac{a}{b} = \frac{c}{d}$$
- Use aligned environments for equation solving

ERROR DETECTION PATTERNS:
- Sign errors: Check if student dropped a negative
- Distribution errors: Check if (a+b)² was expanded correctly
- Unit/rate confusion: Verify rates vs. totals
- Scope misreading (verbal): Check if answer matches question scope

REFUSALS:
- "Can you give me real GRE questions?" → "I can provide practice similar to GRE style, but not actual test content."
- "Just tell me the answer" → "I want to help you understand this. Let's work through it together. [proceed with hints]"
- Off-topic → "I'm here to help with GRE prep. [redirect]"

RESPONSE STRUCTURE:
1. Acknowledge what the student did/said
2. Address any errors gently
3. Provide appropriate-level guidance
4. End with a question or suggested next step
5. Keep responses concise (50-150 words unless explaining complex concepts)

OPTIONAL DEEPER DIVE:
After explanations, offer: "Would you like me to explain [related concept] in more detail?"
```

### 10.2 AWA Scoring Prompt

```
ROLE: You are an expert GRE Analytical Writing scorer. Score essays using the official ETS rubric criteria.

RUBRIC (6-point scale):

Score 6: Outstanding
- Insightful position with compelling support
- Ideas are logically organized and connected
- Varied sentence structure and precise vocabulary
- May have minor errors that don't impede meaning

Score 5: Strong
- Clear position with thoughtful support
- Generally well-organized
- Good control of language with occasional minor errors

Score 4: Adequate
- Competent position with adequate support
- Satisfactorily organized
- Adequate control of language; some errors present

Score 3: Limited
- Position may be vague or inadequately supported
- Organization may be weak
- Limited control of language; errors may obscure meaning

Score 2: Seriously Flawed
- Unclear position or little development
- Disorganized
- Serious and frequent language errors

Score 1: Fundamentally Deficient
- Little or no evidence of understanding the task
- Severe language problems throughout

SCORING PROCESS:
1. Read the entire essay first
2. Score each criterion (thesis, development, organization, language, mechanics) on 1-6
3. Determine holistic score (not a simple average—weight development and thesis higher)
4. Extract specific evidence for each criterion
5. Identify 2-3 strengths with quotes
6. Identify 2-3 improvement areas with specific suggestions
7. Provide actionable revision guidance

OUTPUT FORMAT:
{
  "overallScore": 4,
  "criteriaScores": {...},
  "strengths": ["Quote + explanation"],
  "improvements": ["Issue + specific suggestion"],
  "revisionSuggestions": ["Concrete action items"]
}

BIAS CHECKS:
- Score based on argumentation quality, not position taken
- Do not penalize unconventional but well-supported viewpoints
- Ignore demographic markers; focus only on writing quality
```

### 10.3 Content Generation Prompt (Quant Item)

```
ROLE: You are a GRE content developer creating high-quality Quantitative Reasoning items.

TARGET SPECIFICATIONS:
- Section: Quantitative Reasoning
- Type: {qc | ps | numeric_entry | multiple_select}
- Subskill: {specified subskill}
- Difficulty: {specified tier 1-4}
- Target b-parameter: {approximate value}

REQUIREMENTS:

STYLE:
- Match official GRE tone: clear, precise, no unnecessary complexity
- Avoid proper nouns, brand names, or culturally specific content
- Use standard mathematical notation
- For word problems: use generic contexts (train, factory, percentage, ratio)

MATHEMATICAL ACCURACY:
- All answer options must be mathematically sound
- Correct answer must be unambiguous
- For QC: ensure the comparison is definitively determinable (or definitively indeterminate for D answers)

DISTRACTORS:
- Each wrong answer should result from a specific, common error
- Document the error pattern for each distractor
- Distractors should be plausible to someone who made the documented error

DIFFICULTY CALIBRATION:
Tier 1 (easy): Single concept, straightforward application, b ≈ -1.5 to -0.5
Tier 2 (medium): May combine concepts, standard complexity, b ≈ -0.5 to 0.5
Tier 3 (hard): Multiple steps or non-obvious approach, b ≈ 0.5 to 1.5
Tier 4 (very hard): Complex reasoning or unusual setup, b ≈ 1.5 to 2.5

OUTPUT FORMAT:
{
  "stem": "...",
  "choices": [...],
  "correctAnswer": "...",
  "explanation": "...",
  "distractorRationales": {...},
  "subskill": "...",
  "estimatedDifficulty": {...},
  "conceptTags": [...],
  "strategyTags": [...]
}

POST-GENERATION VALIDATION:
- Solve the problem yourself and verify the answer
- Check that distractors result from documented errors
- Verify no ambiguity in question or answer
- Confirm difficulty aligns with target tier
```

---

## 11) Analytics and Experimentation

### 11.1 Event Taxonomy

| Event | Trigger | Properties |
|-------|---------|------------|
| `session_start` | User begins any activity | session_type, planned_duration |
| `session_complete` | User ends activity | session_type, actual_duration, items_completed |
| `session_abandon` | User exits without completing | session_type, duration_at_abandon, items_completed |
| `item_presented` | Question shown to user | item_id, subskill, difficulty, session_type |
| `item_answered` | User submits answer | item_id, response, is_correct, response_time_ms, hints_used |
| `hint_requested` | User asks for hint | item_id, hint_level, time_before_hint |
| `tutor_message_sent` | User sends chat message | session_id, message_length, item_context |
| `vocab_review` | Flashcard reviewed | word_id, quality_rating, response_time_ms, mode |
| `plan_task_completed` | Study plan task done | task_id, task_type, on_schedule |
| `plan_task_skipped` | Study plan task missed | task_id, task_type, days_overdue |
| `essay_submitted` | AWA essay submitted | prompt_id, word_count, writing_time |
| `exam_completed` | Practice test finished | exam_id, section_scores, completion_time |
| `paywall_viewed` | Paywall screen shown | trigger_point, user_tier |
| `purchase_initiated` | User starts purchase | product_id, price |
| `purchase_completed` | Successful purchase | product_id, price, trial_conversion |

### 11.2 Core Metrics

| Metric | Definition | Target |
|--------|------------|--------|
| **WAL** (Weekly Active Learners) | Unique users completing ≥1 practice item in 7 days | Growth: +10% MoM |
| **Plan Adherence %** | Tasks completed / tasks scheduled | >70% for retained users |
| **Mastery Velocity** | Subskills promoted to Proficient / week | >0.5 subskills/week |
| **Time to First Mastery** | Days from signup to first subskill mastered | <14 days |
| **Predicted Score Lift** | Δ between diagnostic and latest estimate | >5 points in 4 weeks |
| **Tutor Engagement Rate** | % of sessions with tutor interaction | >30% |
| **Vocab Retention Rate** | % of words retained at 30-day mark | >80% |
| **Exam Completion Rate** | % of started practice tests completed | >85% |
| **Session Length** | Avg minutes per session | 20-35 min optimal |
| **Streak Retention** | % of users maintaining 7+ day streaks | >40% |
| **Trial Conversion** | % of trial users converting to paid | >15% |
| **NPS** | Net Promoter Score | >50 |

### 11.3 A/B Testing Plan

| Experiment | Hypothesis | Metric | Guardrail |
|------------|------------|--------|-----------|
| **Hint Aggressiveness** | More proactive hints → faster mastery | Mastery Velocity | Accuracy shouldn't drop |
| **Review Mix Ratio** | 70% new / 30% review → better retention | Vocab Retention | Session completion shouldn't drop |
| **Reminder Timing** | Evening reminders → higher adherence | Plan Adherence | Unsubscribe rate |
| **Difficulty Targeting** | 65% vs 70% accuracy target | Mastery Velocity + Engagement | Neither metric should drop >10% |
| **Streak Incentives** | Badges vs. unlocks vs. none | Streak Retention | Time on platform shouldn't artificially inflate |

**Testing Protocol**:
- Minimum 2-week duration
- Statistical power: 80%, α = 0.05
- Guardrail metrics monitored daily
- Learning outcomes weighted higher than engagement

---

## 12) Monetization and Packaging

### 12.1 Tier Structure

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | 100 practice items, 1 practice test, basic tutor (10 messages/day), 200 vocab words, no study plan |
| **Plus** | $29/month | 2,000 items, 3 practice tests, unlimited tutor, 1,500 vocab words, basic analytics, standard study plan |
| **Pro** | $99/month | Full 5,000+ bank, unlimited tests, AWA scoring, advanced analytics, adaptive study plan, priority support, score guarantee |
| **Pro + Coaching** | $199/month | Pro + 2 hours/month human tutor sessions (partner network) |

### 12.2 Score Improvement Guarantee

**Terms**:
- Eligible: Pro tier, ≥6 weeks active, ≥70% plan adherence
- Guarantee: If official GRE score doesn't improve ≥5 points over verified diagnostic, 100% refund of subscription fees
- Verification: User provides official score report

### 12.3 StoreKit 2 Implementation

```swift
@Observable
class SubscriptionManager {
    var currentEntitlement: Entitlement = .free
    var availableProducts: [Product] = []

    func purchase(_ product: Product) async throws -> Transaction {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateEntitlement(from: transaction)
            await transaction.finish()
            return transaction

        case .userCancelled:
            throw PurchaseError.cancelled

        case .pending:
            throw PurchaseError.pending
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await updateEntitlement(from: transaction)
                await transaction.finish()
            }
        }
    }
}
```

### 12.4 Paywall Strategy

**Trigger Points** (ethical upsell):
- After completing free practice test: "Unlock detailed analytics and more tests"
- When hitting free tutor limit: "Continue your conversation with Pro"
- After diagnostic: "Your personalized plan requires Pro to access"
- Before AWA practice: "AWA scoring is a Pro feature"

**Copy Principles**:
- Lead with value, not restriction
- Show predicted outcome improvement
- Emphasize time efficiency ("study 40% less")
- Social proof (testimonials, cohort success rates)

**Free Trial**: 7-day Pro trial, no credit card required initially (card at day 5)

---

## 13) Roadmap (90 Days)

### Weeks 0-2: Foundation

**Goals**: Diagnostic working, data model complete, content tooling operational

| Task | Owner | Dependencies |
|------|-------|--------------|
| Expand SwiftData models (Question, Attempt, Subskill, Mastery) | iOS Eng | - |
| Build diagnostic flow (30-item adaptive) | iOS Eng | Models |
| Implement IRT ability estimation (EAP) | Algorithm Eng | Models |
| Create content generation prompts + validators | Content Eng | - |
| Generate + QA 300 pilot items | Content + Expert | Prompts |
| Build content admin tooling (upload, tag, review) | Backend Eng | - |
| Pilot item calibration infrastructure | Algorithm Eng | Content |

**Staffing**: 2 iOS, 1 Algorithm, 1 Backend, 1 Content Eng, 1 Quant Expert, 1 Verbal Expert

### Weeks 3-6: Core Engine

**Goals**: IRT engine powering adaptive practice, Exam Mode v1, AWA Lab v1

| Task | Owner | Dependencies |
|------|-------|--------------|
| Adaptive item selection (max info + constraints) | Algorithm Eng | IRT |
| BKT mastery tracking per subskill | Algorithm Eng | IRT |
| Exam Mode UI (timer, calculator, review flags) | iOS Eng | - |
| Exam Mode scoring + analytics | iOS Eng + Algo | Models |
| AWA writing interface (timed, word count) | iOS Eng | - |
| AWA AI scoring pipeline | AI Eng | Prompts |
| Vocabulary expansion to 1,000 words | Content Eng | - |
| Content pipeline: scale to 1,500 items | Content + Experts | Tooling |

**Staffing**: 2 iOS, 1 Algorithm, 1 AI Eng, 1 Backend, 2 Content, 2 Experts

### Weeks 7-10: Intelligence Layer

**Goals**: Tutor Chat+, analytics dashboard, study plans, bank to 2,000

| Task | Owner | Dependencies |
|------|-------|--------------|
| Tutor Chat+ tools (calculator, whiteboard) | iOS + AI Eng | - |
| Math rendering (LaTeX) | iOS Eng | - |
| Progress analytics views | iOS Eng | Models |
| Score prediction + confidence intervals | Algorithm Eng | IRT calibration |
| Study plan generation algorithm | Algorithm Eng | Mastery |
| Study plan UI (calendar, tasks, rescheduling) | iOS Eng | Models |
| CloudKit sync implementation | iOS Eng | Models |
| Content pipeline: scale to 2,000 items | Content + Experts | - |

**Staffing**: 2 iOS, 1 Algorithm, 1 AI Eng, 2 Content, 2 Experts

### Weeks 11-13: Polish & Launch Prep

**Goals**: Accessibility, offline hardening, paywall, beta

| Task | Owner | Dependencies |
|------|-------|--------------|
| Accessibility audit + fixes (VoiceOver, Dynamic Type) | iOS Eng | - |
| Offline mode hardening + sync queue | iOS Eng | CloudKit |
| StoreKit 2 paywall implementation | iOS Eng | - |
| Paywall UI + copy | Design + iOS | - |
| Performance optimization (token streaming, prefetch) | iOS + Backend | - |
| QA: end-to-end testing, latency validation | QA | All |
| Beta launch (TestFlight, 100 users) | All | All |
| Gather feedback, prioritize fixes | PM | Beta |
| Go/no-go decision | Leadership | Beta results |

**Staffing**: 2 iOS, 1 QA, 1 Design, PM, leadership

### Dependencies Graph

```
Content Tooling ──┬──▶ Pilot Items ──▶ IRT Calibration ──▶ Adaptive Engine
                  │
                  └──▶ Scaled Content ──────────────────▶ Full Bank

Models ──▶ Diagnostic ──▶ IRT Engine ──▶ Mastery Tracking ──▶ Study Plans
       │
       └──▶ Exam Mode ──▶ Scoring ──▶ Analytics

AI Prompts ──▶ AWA Scoring ──▶ AWA Lab
          │
          └──▶ Tutor Prompts ──▶ Tutor Chat+
```

---

## 14) QA and Compliance

### 14.1 Automated Item Validators

| Validator | Checks | Threshold |
|-----------|--------|-----------|
| **Style Conformity** | Question structure matches GRE format | Binary pass/fail |
| **Deduplication** | Embedding similarity to existing items | < 0.85 similarity |
| **Math Verification** | Symbolic solver confirms answer | Must match |
| **Bias Screening** | Demographic/stereotype flags | Zero flags |
| **Reading Level** | Flesch-Kincaid for passages | Grade 12-16 |
| **Plagiarism** | Cross-reference test prep sources | < 0.90 similarity |

### 14.2 AI Eval Harness

```python
class TutorEval:
    """
    Evaluate tutor responses for quality and safety.
    """

    def eval_response(self, context: TutorContext, response: str) -> EvalResult:
        checks = [
            self.check_no_premature_answer(context, response),
            self.check_math_correctness(context, response),
            self.check_appropriate_hint_level(context, response),
            self.check_encouragement_present(response),
            self.check_question_or_next_step(response),
            self.check_length_appropriate(response),
        ]
        return EvalResult(checks=checks, passed=all(c.passed for c in checks))

class AWAScorerEval:
    """
    Evaluate AWA scoring consistency.
    """

    def eval_scoring(self, essay: str, feedback: EssayFeedback) -> EvalResult:
        checks = [
            self.check_score_in_range(feedback.overallScore),
            self.check_evidence_cited(feedback),
            self.check_actionable_suggestions(feedback),
            self.check_bias_neutrality(essay, feedback),
            self.check_rubric_alignment(feedback),
        ]
        return EvalResult(checks=checks, passed=all(c.passed for c in checks))
```

### 14.3 Performance SLOs

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Tutor response latency (p95) | < 3s | > 5s |
| Item load latency | < 200ms | > 500ms |
| App cold start | < 2s | > 4s |
| CloudKit sync latency | < 5s | > 15s |
| Crash rate | < 0.1% | > 0.5% |
| API error rate | < 1% | > 3% |

### 14.4 Disaster Recovery

- SwiftData local persistence: survives app crashes
- CloudKit: automatic backup to iCloud
- Content updates: rollback capability via versioning
- AI failures: graceful degradation (show stored explanations)

### 14.5 Legal and Compliance

**ETS Non-Affiliation**:
- Clear disclaimer: "IGA is not affiliated with or endorsed by ETS."
- No use of "GRE" in app name or logo
- No reproduction of actual test content

**GDPR/CCPA**:
- Privacy policy clearly states data collection
- User can request data export (Article 20)
- User can request deletion (Article 17)
- Opt-in analytics with granular controls
- Data retention: 2 years active, 90 days post-deletion

**Content IP**:
- All items generated original or licensed
- Passages adapted from public domain or licensed sources
- Clear documentation of provenance
- No copyrighted test content

---

## 15) Examples

### 15.1 Exemplar Quant Item

**Question Spec**:

```yaml
ID: q-quant-demo-001
Section: Quantitative Reasoning
Subtype: Problem Solving (Single Answer)
Subskill: Q-WP (Word Problems)
Difficulty: Tier 2 (Medium)
Estimated b: 0.2

Stem: |
  A store sells notebooks for $3 each and pens for $1.50 each.
  If a customer buys a total of 10 items and spends exactly $24,
  how many notebooks did the customer buy?

Choices:
  A: 4
  B: 5
  C: 6
  D: 7
  E: 8

Correct Answer: C

Explanation: |
  Let n = number of notebooks and p = number of pens.

  We have two equations:
  n + p = 10 (total items)
  3n + 1.50p = 24 (total cost)

  From the first equation: p = 10 - n
  Substituting: 3n + 1.50(10 - n) = 24
  3n + 15 - 1.50n = 24
  1.50n = 9
  n = 6

  Verification: 6 notebooks ($18) + 4 pens ($6) = $24 ✓

Distractor Rationales:
  A: Result of arithmetic error (1.5n = 6)
  B: Common "split evenly" guess
  D: Sign error in substitution
  E: Reversed notebook/pen calculation

IRT Params:
  a: 1.1
  b: 0.2
  c: 0.20

Time Benchmark: 120 seconds

Concept Tags: [systems of equations, substitution, word problems]
Strategy Tags: [set up equations, substitute, verify]
```

### 15.2 Exemplar Verbal Item

**Question Spec**:

```yaml
ID: q-verbal-demo-001
Section: Verbal Reasoning
Subtype: Sentence Equivalence
Subskill: V-SE
Difficulty: Tier 3 (Hard)
Estimated b: 0.8

Stem: |
  The researcher's conclusions, though initially met with _______ by
  the scientific community, were eventually vindicated by subsequent
  studies that confirmed her methodology was sound.

Choices (Select TWO that produce equivalent sentences):
  A: acclaim
  B: skepticism
  C: indifference
  D: incredulity
  E: enthusiasm
  F: hostility

Correct Answers: B, D

Explanation: |
  The sentence structure indicates contrast: "though initially met with X...
  were eventually vindicated." This signals that the initial reaction was
  negative or doubtful, while the eventual outcome was positive.

  "Skepticism" (doubt about truth/validity) and "incredulity" (disbelief)
  both convey initial doubt that was later overcome.

  "Acclaim" and "enthusiasm" are positive—wrong direction.
  "Indifference" is neutral, not fitting the "vindicated" contrast.
  "Hostility" is too strong and doesn't specifically relate to doubting
  the research's validity.

Distractor Rationales:
  A: Misreads "vindicated" as requiring initial praise
  C: Ignores the contrast structure
  E: Same as A
  F: Tempting but too strong; "hostility" implies personal animosity

IRT Params:
  a: 1.3
  b: 0.8
  c: 0.10 (2 correct from 6, harder to guess)

Time Benchmark: 90 seconds

Concept Tags: [contrast signals, connotation, academic vocabulary]
Strategy Tags: [identify structure, predict before looking, match pairs]
```

### 15.3 AWA Prompt with Scoring Sample

**Prompt**:

```
"Educational institutions should actively encourage students to
question and criticize the ideas presented in their courses."

Write a response in which you discuss the extent to which you agree
or disagree with the statement. Explain your reasoning and support
your position with examples.
```

**Sample Essay (Score 4)**:

```
I largely agree that educational institutions should encourage students
to question and criticize ideas presented in courses. Critical thinking
is essential for intellectual development and preparing students for
real-world challenges.

First, questioning promotes deeper understanding. When students simply
accept information passively, they often forget it quickly. However,
when they engage critically with material, asking "why" and "how," they
develop genuine comprehension. For example, in my history class, students
who questioned the causes of World War I remembered the material better
than those who just memorized dates.

Second, criticism develops important skills. In professional environments,
employers value workers who can evaluate information and identify problems.
By practicing these skills in school, students become more valuable
contributors to society.

However, I acknowledge some limits to this position. Very young students
may not have the background knowledge to criticize ideas constructively.
Also, some fundamental concepts in fields like mathematics must be accepted
before they can be meaningfully questioned.

In conclusion, while there are some exceptions, educational institutions
should generally encourage questioning and criticism to develop critical
thinking skills and deeper learning.
```

**AI Scoring Feedback**:

```json
{
  "overallScore": 4,
  "criteriaScores": {
    "thesisClarity": 4,
    "argumentDevelopment": 4,
    "evidenceQuality": 3,
    "organizationFlow": 5,
    "languageSophistication": 4,
    "grammarMechanics": 5
  },
  "strengths": [
    "Clear organizational structure with distinct paragraphs for each point",
    "Effective acknowledgment of counterargument in paragraph 4",
    "Thesis is stated clearly and position is consistent throughout"
  ],
  "improvements": [
    "Evidence could be stronger: The history class example is somewhat generic. Consider a more specific, developed example showing exactly how questioning led to better understanding.",
    "The second body paragraph lacks concrete evidence entirely. Add a specific example of how criticism develops professional skills.",
    "The 'some fundamental concepts' point in the counterargument could be developed with a specific example."
  ],
  "revisionSuggestions": [
    "Replace the generic history class example with a specific scenario (name a topic, describe the questioning process, show the outcome)",
    "Add one concrete example in paragraph 3 from a real workplace or academic setting",
    "Conclusion could be strengthened by restating the main arguments rather than just the position"
  ]
}
```

### 15.4 Vocabulary Entry

```yaml
Word: ephemeral
Part of Speech: adjective

Definitions:
  - context: general
    definition: lasting for a very short time
    usage: "used to describe things that are temporary or fleeting"
  - context: biology
    definition: (of plants) having a very short life cycle
    usage: "often used in botanical contexts"

Roots:
  - root: ephemer-
    origin: Greek
    meaning: lasting only a day
    related_words: [ephemera, ephemeris]

Synonyms:
  - word: fleeting
    nuance: emphasizes the quick passage
  - word: transient
    nuance: emphasizes impermanence
  - word: evanescent
    nuance: more literary, suggests fading away

Antonyms: [permanent, enduring, eternal, lasting]

Collocations:
  - ephemeral nature
  - ephemeral beauty
  - ephemeral pleasures
  - ephemeral fame

Example Sentences:
  - "The ephemeral nature of social media trends makes it difficult for marketers to plan long-term strategies."
  - "Critics dismissed the movement as ephemeral, but its influence persisted for decades."
  - "She captured the ephemeral beauty of the cherry blossoms in her photographs."

Mnemonic: "E-FEM-eral sounds like 'a FEMale mayfly'—mayflies live only one day, making them ephemeral creatures."

Audio URL: /audio/ephemeral.mp3
Mnemonic Image URL: /images/mayfly-ephemeral.jpg

GRE Frequency: common (appears 2-3 times per year on average)
Difficulty Rating: 5.5 / 10

Exercises:
  - type: definition
    prompt: "Choose the definition of 'ephemeral'"
    correct: "lasting for a very short time"

  - type: cloze
    prompt: "The _______ popularity of the app surprised its developers, who expected lasting success."
    answer: ephemeral

  - type: synonym_pair
    prompt: "Select the two words closest in meaning to 'ephemeral'"
    options: [permanent, fleeting, substantial, transient]
    correct: [fleeting, transient]
```

### 15.5 Study Plan Week Snapshot

```yaml
User: Maya (Quant-Anxious persona)
Week: 3 of 8
Target Score: Q155, V160 (315 total)
Current Estimate: Q148, V158 (306)
Weekly Hours Allocated: 10

Monday:
  - task: Quant Algebra Drill
    duration: 30 min
    subskill: Q-AL
    rationale: Lowest mastery subskill (42%)
    status: completed

  - task: Vocab Review
    duration: 15 min
    words_due: 23
    status: completed

Tuesday:
  - task: RC Passage Practice
    duration: 25 min
    passages: 2
    status: completed

  - task: Tutor Session - Word Problems
    duration: 20 min
    subskill: Q-WP
    rationale: Second-lowest mastery (48%)
    status: completed

Wednesday:
  - task: Rest Day (Light Vocab)
    duration: 10 min
    status: completed

Thursday:
  - task: Mixed Quant Practice
    duration: 30 min
    subskills: [Q-AL, Q-AR, Q-WP]
    difficulty: adaptive
    status: pending

  - task: SE Strategy Review
    duration: 15 min
    status: pending

Friday:
  - task: Timed Verbal Section
    duration: 25 min
    mode: exam_simulation
    status: pending

Saturday:
  - task: Quant Intensive - Geometry
    duration: 45 min
    subskill: Q-GE
    rationale: Diagnostic flagged as weakness
    status: pending

  - task: AWA Practice (untimed)
    duration: 30 min
    status: pending

Sunday:
  - task: Week Review
    duration: 20 min
    activity: Review mistake journal, adjust plan
    status: pending

  - task: Light Vocab
    duration: 10 min
    status: pending

Weekly Goals:
  - Complete 80+ practice items
  - Improve Q-AL mastery to 55%+
  - Learn 35 new vocab words
  - Complete 1 AWA essay

Progress vs. Last Week:
  - Items completed: 87 → target 80 ✓
  - Q-AL mastery: 38% → 42% (+4%)
  - Vocab words learned: 31
  - Plan adherence: 85%
```

### 15.6 Analytics Dashboard Mock Description

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          PROGRESS DASHBOARD                                 │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PREDICTED SCORE                          STUDY STREAK                      │
│  ┌─────────────────────┐                 ┌─────────────────────┐            │
│  │                     │                 │                     │            │
│  │    Q: 152 ± 4       │                 │     🔥 12 days      │            │
│  │    V: 158 ± 3       │                 │    Best: 18 days    │            │
│  │    ─────────────    │                 │                     │            │
│  │    Total: 310       │                 │  ○○○○○●●●●●●●       │            │
│  │    Target: 315      │                 │  [This week]        │            │
│  │                     │                 │                     │            │
│  └─────────────────────┘                 └─────────────────────┘            │
│                                                                             │
│  MASTERY BY SUBSKILL                                                        │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                                                               │          │
│  │  Q-Arithmetic    ████████████████████░░░░  78% ▲ Proficient  │          │
│  │  Q-Algebra       ████████░░░░░░░░░░░░░░░░  42% → Developing  │          │
│  │  Q-Geometry      ██████████░░░░░░░░░░░░░░  52% ▲ Developing  │          │
│  │  Q-Word Prob     ████████████░░░░░░░░░░░░  55% ▲ Developing  │          │
│  │  Q-Data Analysis █████████████████░░░░░░░  68% ▲ Proficient  │          │
│  │  ────────────────────────────────────────────────────────────│          │
│  │  V-Sent Equiv    ████████████████████████  85% ★ Mastered   │          │
│  │  V-Text Comp     ██████████████████░░░░░░  72% → Proficient  │          │
│  │  V-RC Detail     ████████████████░░░░░░░░  65% ▲ Proficient  │          │
│  │  V-RC Structure  █████████████████░░░░░░░  70% → Proficient  │          │
│  │                                                               │          │
│  └──────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  WEEKLY METRICS                           THIS WEEK'S FOCUS                 │
│  ┌─────────────────────┐                 ┌─────────────────────┐            │
│  │                     │                 │                     │            │
│  │  Items: 87/80 ✓     │                 │  Priority: Q-AL     │            │
│  │  Time: 8.5 hrs      │                 │  "Algebra needs     │            │
│  │  Accuracy: 68%      │                 │  focused practice.  │            │
│  │  Avg Time: 92s      │                 │  3 drill sessions   │            │
│  │  Hints: 12 used     │                 │  scheduled."        │            │
│  │  Adherence: 85%     │                 │                     │            │
│  │                     │                 │  [Start Drill]      │            │
│  └─────────────────────┘                 └─────────────────────┘            │
│                                                                             │
│  SCORE TREND (Last 4 Weeks)                                                 │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │  320 ┤                                              Target   │          │
│  │      │                                         ─ ─ ─ ─ ─ ─  │          │
│  │  310 ┤                              ●─────●                  │          │
│  │      │                    ●─────●───                         │          │
│  │  300 ┤        ●─────●───                                     │          │
│  │      │  ●────                                                │          │
│  │  290 ┤                                                       │          │
│  │      └──────────────────────────────────────────────────────│          │
│  │       Wk1    Wk2    Wk3    Wk4    Wk5    Wk6    Wk7    Wk8  │          │
│  └──────────────────────────────────────────────────────────────┘          │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary

This specification provides a comprehensive blueprint for transforming IGA from an MVP into a premium GRE preparation platform worth $100/month. The key value drivers are:

1. **Psychometric rigor**: IRT-based adaptive engine with per-subskill mastery tracking
2. **AI-powered tutoring**: On-demand Socratic tutoring replacing expensive human tutors
3. **Measurable outcomes**: Diagnostic → predicted score → progress tracking → guarantee
4. **Elite content**: 5,000+ calibrated items, 2,500 vocabulary words, 200 AWA prompts
5. **Personalized paths**: Diagnostic-driven study plans that adapt to progress

The 90-day roadmap is aggressive but achievable with the specified staffing. Critical path items are diagnostic/IRT engine (enables everything else) and content pipeline (bottleneck for quality at scale).
