// IGA/Features/Vocab/VocabListView.swift

import SwiftUI

// MARK: - Vocabulary List View

/// Main view for browsing and studying vocabulary
struct VocabListView: View {
    @State private var viewModel: VocabViewModel

    init(viewModel: VocabViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @MainActor
    init() {
        _viewModel = State(initialValue: VocabViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                if let stats = viewModel.stats {
                    statsHeader(stats)
                }

                // Search bar
                searchBar

                // Word list or review mode
                if viewModel.isReviewing, let session = viewModel.reviewSession {
                    FlashcardReviewView(
                        session: session,
                        onComplete: { Task { await viewModel.endReviewSession() } },
                        onRecordQuality: { quality in
                            Task { await viewModel.recordReview(quality: quality) }
                        }
                    )
                } else {
                    wordList
                }
            }
            .navigationTitle("Vocabulary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.startReviewSession() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.stack")
                            if viewModel.dueCount > 0 {
                                Text("\(viewModel.dueCount)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.Colors.primaryFallback)
                                    .foregroundColor(.white)
                                    .cornerRadius(Theme.CornerRadius.pill)
                            }
                        }
                    }
                }
            }
            .sheet(item: $viewModel.selectedWord) { word in
                WordDetailView(
                    word: word,
                    relatedWords: viewModel.relatedWords,
                    onDismiss: { viewModel.clearSelection() }
                )
            }
        }
        .task {
            await viewModel.loadWords()
        }
    }

    // MARK: - Stats Header

    private func statsHeader(_ stats: VocabStats) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            statItem(value: "\(stats.totalWords)", label: "Total")
            statItem(value: "\(stats.dueForReview)", label: "Due", highlight: stats.dueForReview > 0)
            statItem(value: "\(stats.mastered)", label: "Mastered")
            statItem(value: "\(Int(stats.masteryPercentage * 100))%", label: "Progress")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
    }

    private func statItem(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.title3)
                .foregroundColor(highlight ? Theme.Colors.primaryFallback : .primary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search words...", text: $viewModel.searchText)
                .textFieldStyle(.plain)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(Theme.Spacing.md)
    }

    // MARK: - Word List

    private var wordList: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "Loading vocabulary...")
            } else if viewModel.filteredWords.isEmpty {
                emptyState
            } else {
                List(viewModel.filteredWords) { word in
                    WordRowView(word: word)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await viewModel.selectWord(word) }
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(viewModel.searchText.isEmpty ? "No vocabulary words yet" : "No matching words")
                .font(Theme.Typography.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Word Row View

struct WordRowView: View {
    let word: VocabWord

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(word.headword)
                    .font(Theme.Typography.bodyBold)

                Text(word.posAbbreviation)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if word.isDueForReview {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.primaryFallback)
                }
            }

            Text(word.definition)
                .font(Theme.Typography.callout)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Word Detail View

struct WordDetailView: View {
    let word: VocabWord
    let relatedWords: [VocabWord]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(word.headword)
                            .font(Theme.Typography.largeTitle)

                        Text(word.posAbbreviation)
                            .font(Theme.Typography.title3)
                            .foregroundColor(.secondary)
                    }

                    // Definition
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Definition")
                            .font(Theme.Typography.bodyBold)
                            .foregroundColor(.secondary)

                        Text(word.definition)
                            .font(Theme.Typography.body)
                    }

                    // Example
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Example")
                            .font(Theme.Typography.bodyBold)
                            .foregroundColor(.secondary)

                        Text(word.example)
                            .font(Theme.Typography.body)
                            .italic()
                    }

                    // Synonyms
                    if !word.synonyms.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Synonyms")
                                .font(Theme.Typography.bodyBold)
                                .foregroundColor(.secondary)

                            FlowLayout(spacing: Theme.Spacing.xs) {
                                ForEach(word.synonyms, id: \.self) { synonym in
                                    Text(synonym)
                                        .font(Theme.Typography.callout)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xs)
                                        .background(Theme.Colors.primaryFallback.opacity(0.1))
                                        .cornerRadius(Theme.CornerRadius.pill)
                                }
                            }
                        }
                    }

                    // Related Words
                    if !relatedWords.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Related Words")
                                .font(Theme.Typography.bodyBold)
                                .foregroundColor(.secondary)

                            ForEach(relatedWords) { related in
                                HStack {
                                    Text(related.headword)
                                        .font(Theme.Typography.body)
                                    Text("- \(related.definition)")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    VocabListView(viewModel: .preview)
}
