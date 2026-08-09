import SwiftUI
import UniformTypeIdentifiers
import WingmanCore

struct MemoriesView: View {
  @Bindable var model: AppModel
  @State private var newMemoryText = ""
  @State private var isImporting = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.lg) {
        VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.xs) {
          Text("What Wingman remembers")
            .font(WingmanType.subheadline(.semibold))
            .foregroundStyle(WingmanPalette.meshInkSecondary)
          Text("Your style, in your words")
            .font(.system(size: 30, weight: .heavy))
            .foregroundStyle(WingmanPalette.meshInk)
        }
        .padding(.top, WingmanMetrics.Spacing.sm)

        writingStyleSection
        memoriesSection
        importSection
      }
      .padding()
    }
    .background(WingmanMeshBackground().ignoresSafeArea())
    // These screens are a committed light surface (mesh gradient + fixed
    // mesh ink colors) — force light mode for everything in the subtree so
    // shared components (wingmanCard, ReplySuggestionCard, etc.) resolve
    // their adaptive colors to light too, instead of going dark-card-on-
    // light-mesh inconsistent when the system is in Dark Mode.
    .preferredColorScheme(.light)
    .navigationBarTitleDisplayMode(.inline)
    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let url):
        model.importMacGraph(from: url)
      case .failure(let error):
        model.lastError = error.localizedDescription
      }
    }
  }

  private var writingStyleSection: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.md) {
      Text("Writing style")
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)

      WingmanTextEditor(
        "How you naturally write (casual, uses emoji sparingly, short sentences…)",
        text: $model.state.writingStyle.toneNotes,
        lineLimit: 2...5
      )
      WingmanTextEditor(
        "Grammar preferences (Oxford comma, British spelling…)",
        text: $model.state.writingStyle.grammarPreferences,
        lineLimit: 1...3
      )

      VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.xs) {
        Text("Signature phrases")
          .font(WingmanType.caption())
          .foregroundStyle(WingmanPalette.inkSecondary)
        ChipListField(placeholder: "sounds good, no worries at all", values: $model.state.writingStyle.signaturePhrases)
      }

      VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.xs) {
        Text("Avoid")
          .font(WingmanType.caption())
          .foregroundStyle(WingmanPalette.inkSecondary)
        ChipListField(placeholder: "exclamation points, corporate phrasing", values: $model.state.writingStyle.thingsToAvoid)
      }

      Button {
        model.save()
      } label: {
        Label("Save style", systemImage: "checkmark")
      }
      .buttonStyle(.wingmanSecondary)
    }
    .wingmanCard(radius: WingmanMetrics.Radius.lg)
  }

  private var memoriesSection: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.md) {
      Text("Memories")
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)

      HStack(spacing: WingmanMetrics.Spacing.sm) {
        WingmanTextField("Add something worth remembering", text: $newMemoryText)
        Button {
          model.addMemory(newMemoryText)
          newMemoryText = ""
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.wingmanIcon)
        .disabled(newMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if model.state.memories.isEmpty {
        WingmanEmptyState(
          icon: "sparkle",
          title: "No memories yet",
          message: "Add facts worth remembering, or import a graph built from your Mac Messages history below."
        )
      } else {
        VStack(spacing: WingmanMetrics.Spacing.xs) {
          ForEach(model.state.memories.sorted(by: { $0.createdAt > $1.createdAt })) { memory in
            MemoryRow(memory: memory) {
              model.removeMemory(id: memory.id)
            }
          }
        }
      }
    }
    .wingmanCard(radius: WingmanMetrics.Radius.lg)
  }

  private var importSection: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
      Text("On-device graph")
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)
      Text("`wingman-history build-graph` on your Mac turns the watch log into a JSON file of deterministic, frequency-based facts — no automatic sync yet, so bring the file over yourself (AirDrop, Files, iCloud Drive) and import it here. Re-importing replaces the previous Mac-derived memories without touching the ones you wrote yourself.")
        .font(WingmanType.caption())
        .foregroundStyle(WingmanPalette.inkSecondary)
      Button {
        isImporting = true
      } label: {
        Label("Import Mac graph…", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(.wingmanSecondary)
    }
    .wingmanCard(radius: WingmanMetrics.Radius.lg)
  }
}

private struct MemoryRow: View {
  let memory: MemoryFact
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: WingmanMetrics.Spacing.sm) {
      VStack(alignment: .leading, spacing: 4) {
        Text(memory.text)
          .font(WingmanType.body())
          .foregroundStyle(WingmanPalette.ink)
      }
      Spacer()
      if memory.source == .macGraph {
        Text("mac")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(WingmanPalette.inkTertiary)
      }
      if memory.source == .userEntered {
        Button(action: onDelete) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.wingmanIcon)
      }
    }
    .padding(.vertical, WingmanMetrics.Spacing.xs)
  }
}
