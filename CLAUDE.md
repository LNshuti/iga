# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IGA (Intelligent GRE Assistant) is an iOS 17+ SwiftUI application for GRE exam preparation. It uses Cerebras-backed inference for AI tutoring, adaptive practice with Elo-style ratings, and SM-2 spaced repetition for vocabulary learning.

## Build & Development Commands

```bash
# Generate Xcode project from project.yml (requires XcodeGen)
xcodegen generate

# Open project
open IGA.xcodeproj

# Build from command line
xcodebuild -scheme IGA -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run all tests
xcodebuild test -scheme IGA -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme IGA -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IGATests/AdaptiveEngineTests

# Clean build
xcodebuild clean -scheme IGA
```

In Xcode: `Cmd+B` to build, `Cmd+R` to run, `Cmd+U` to test.

## Architecture

**Tech Stack:** SwiftUI, SwiftData, Swift 5.9+, iOS 17+

**Pattern:** MVVM with `@Observable` ViewModels and protocol-based dependency injection.

**Directory Structure:**
- `iga/Config/` - AppConfig.swift (runtime config), xcconfig files for API keys
- `iga/Data/Models/` - SwiftData `@Model` classes (Question, VocabWord, Session, UserProgress, Message)
- `iga/Data/Store/` - DataStore (persistence), SeedDataLoader (loads bundled JSON)
- `iga/Data/Seed/` - Bundled questions.json and vocab.json
- `iga/AI/Inference/` - InferenceClient protocol and CerebrasInferenceClient implementation
- `iga/AI/Prompts/` - Prompt builders for tutoring, explanations, question generation
- `iga/Features/` - Vertical feature slices (Home, Practice, TutorChat, Vocab)
- `iga/Shared/` - Reusable components and Theme design system
- `iga/Tests/` - Unit tests organized by domain (AITests, DataTests, FeatureTests)

**Key Components:**
- `AdaptiveEngine` - Elo-style question selection targeting 70% accuracy
- `SpacedRepetition` - SM-2 algorithm for vocabulary review scheduling
- `InferenceClient` - Protocol abstracting AI backends (swap Cerebras for others)
- `DataStore` - Central SwiftData container managing all models

## Configuration

API keys are configured via xcconfig files:

```bash
# Copy template and add credentials
cp iga/Config/Secrets.example.xcconfig iga/Config/Secrets.xcconfig
```

Edit `Secrets.xcconfig`:
```
CEREBRAS_API_BASE_URL = https://api.cerebras.ai/v1
CEREBRAS_API_KEY = your-key-here
TEXT_MODEL_ID = llama3.1-70b
EMBEDDING_MODEL_ID = text-embedding-ada-002
```

For CI/CD, set environment variables instead. AppConfig.swift reads from Info.plist with env var fallback.

**Never commit Secrets.xcconfig** - it's gitignored.

## Offline Mode

The app works offline with bundled seed data. AI features (tutor chat, generated explanations) require network. The app degrades gracefully:
- Practice sessions use seeded questions with stored rationales
- Vocabulary review continues with local SM-2 data

## API Compatibility

The InferenceClient uses OpenAI-compatible endpoints (`/chat/completions`, `/embeddings`). To swap backends, implement the `InferenceClient` protocol.

## Testing

Tests use `@testable import IGA` and mock implementations. DataStore supports in-memory mode for testing via `DataStore(inMemory: true)`.
