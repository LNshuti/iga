# IGA 

IGA is an AI-powered iOS application for GRE preparation, leveraging Cerebras-backed ultra-fast inference to deliver personalized tutoring, adaptive practice sessions, and intelligent vocabulary learning.

## Features

### Tutor Chat
- Conversational GRE tutor with Socratic method pedagogy
- Streaming responses for natural conversation flow
- Question-specific discussions with context awareness
- Math-friendly formatting for quantitative problems

### Practice Sessions
- Timed and untimed practice modes
- Adaptive question selection using Elo-style ratings targeting 70% accuracy
- AI-generated explanations for each question
- Progress tracking by topic and difficulty
- 35 seed questions covering quantitative and verbal sections

### Vocabulary Flashcards
- 100 GRE vocabulary words with definitions and examples
- Spaced repetition system using the SM-2 algorithm
- Semantic similarity using embeddings for related word discovery

### Progress Tracking
- Overall accuracy and streak tracking
- Section-specific performance (Quantitative/Verbal)
- Topic-level ratings and mastery indicators

## Architecture

```
iga/
├── igaApp.swift                    # App entry point
├── Config/                         # Configuration
│   ├── Secrets.example.xcconfig    # Template for API keys
│   ├── Debug.xcconfig              # Debug build settings
│   └── AppConfig.swift             # Runtime configuration
├── Data/
│   ├── Models/                     # SwiftData models
│   ├── Store/                      # Data store and seed loader
│   └── Seed/                       # JSON seed data
├── AI/
│   ├── Inference/                  # Inference client abstraction
│   ├── Prompts/                    # Prompt builders
│   └── Embeddings/                 # Embedding service
├── Features/
│   ├── TutorChat/                  # Chat feature
│   ├── Practice/                   # Practice sessions with adaptive engine
│   ├── Vocab/                      # Vocabulary with spaced repetition
│   └── Home/                       # Home and navigation
├── Shared/
│   ├── Components/                 # Reusable UI components
│   └── Theme/                      # Design system
└── Tests/                          # Unit tests
```

## Requirements

- iOS 17.0+
- Xcode 15+
- Swift 5.9+
- Cerebras API access (or compatible OpenAI-style endpoint)

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/LNshuti/iga.git
cd iga
```

### 2. Configure API Keys

Copy the example configuration and add your API credentials:

```bash
cp iga/Config/Secrets.example.xcconfig iga/Config/Secrets.xcconfig
```

Edit `Secrets.xcconfig`:

```
CEREBRAS_API_BASE_URL = https://api.cerebras.ai/v1
CEREBRAS_API_KEY = your-api-key-here
TEXT_MODEL_ID = llama3.1-70b
EMBEDDING_MODEL_ID = text-embedding-ada-002
```

Never commit `Secrets.xcconfig` to version control. It is already in `.gitignore`.

### 3. Open in Xcode

```bash
open iga.xcodeproj
```

### 4. Build and Run

Select your target device or simulator and press Cmd+R.

## Running Tests

```bash
xcodebuild test -scheme IGA -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or in Xcode: Cmd+U

## Offline Mode

The app works offline with bundled seed data. AI features (explanations, tutor chat) require network connectivity. When offline:

- Practice sessions work with seeded questions and stored rationales
- Vocabulary review continues with local SM-2 data

## API Compatibility

The inference client uses OpenAI-compatible API format. To use a different backend, implement the `InferenceClient` protocol.

### Chat Completions Endpoint
```
POST /chat/completions
{
  "model": "llama3.1-70b",
  "messages": [{"role": "user", "content": "..."}],
  "max_tokens": 1024,
  "temperature": 0.7,
  "stream": true
}
```

### Embeddings Endpoint
```
POST /embeddings
{
  "model": "text-embedding",
  "input": ["text1", "text2"]
}
```

## Key Components

| Component | Description |
|-----------|-------------|
| `InferenceClient` | Protocol for AI inference operations |
| `CerebrasInferenceClient` | Cerebras API implementation |
| `AdaptiveEngine` | Elo-style question selection targeting 70% accuracy |
| `SpacedRepetition` | SM-2 vocabulary review scheduling |
| `DataStore` | SwiftData persistence layer |

## Design Patterns

- MVVM Architecture with `@Observable` ViewModels
- Protocol-based dependency injection for testability
- Feature modules as self-contained vertical slices
- Async/await for modern Swift concurrency

## License

MIT License - see LICENSE file for details.
