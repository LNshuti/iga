// IGA/IGAApp.swift

import SwiftUI
import SwiftData

/// IGA - Intelligent GRE Assistant
/// An AI-powered GRE preparation app using Cerebras inference
@main
struct IGAApp: App {
    @State private var dataStore: DataStore

    init() {
        // Initialize data store
        do {
            _dataStore = State(initialValue: try DataStore())
        } catch {
            fatalError("Failed to initialize DataStore: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataStore)
                .task {
                    await loadSeedData()
                }
        }
        .modelContainer(dataStore.modelContainer)
    }

    /// Load seed data on first launch
    private func loadSeedData() async {
        let loader = SeedDataLoader(dataStore: dataStore)
        do {
            try await loader.loadSeedDataIfNeeded()
        } catch {
            print("Failed to load seed data: \(error)")
        }
    }
}

// MARK: - Content View

/// Root content view that handles initial setup
struct ContentView: View {
    @State private var isReady = false
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if isReady {
                HomeView()
            } else {
                LaunchScreen()
            }
        }
        .task {
            // Simulate brief loading for smooth transition
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation {
                isReady = true
            }
        }
    }
}

// MARK: - Launch Screen

struct LaunchScreen: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // App icon placeholder
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primaryFallback, Theme.Colors.secondaryFallback],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)

                Text("IGA")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text("Intelligent GRE Assistant")
                .font(Theme.Typography.title3)
                .foregroundColor(.secondary)

            ProgressView()
                .padding(.top, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Environment Keys

private struct DataStoreKey: EnvironmentKey {
    static let defaultValue: DataStore? = nil
}

extension EnvironmentValues {
    var dataStore: DataStore? {
        get { self[DataStoreKey.self] }
        set { self[DataStoreKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
