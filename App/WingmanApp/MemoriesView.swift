import SwiftUI
import UniformTypeIdentifiers
import WingmanCore

struct MemoriesView: View {
  @Bindable var model: AppModel
  @State private var newMemoryText = ""
  @State private var isImporting = false

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        EditorialHeader(
          rubric: "What Wingman remembers",
          title: "Your style, in your words."
        )
        .padding(.bottom, 4)

        writingStyleSection
        memoriesSection
        importSection
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 32)
    }
    .editorialPage()
    // Pushed from Privacy rather than owning a tab, so the bar has to stay:
    // hiding it here would take the back button with it.
    .navigationTitle("Memories")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
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
    VStack(alignment: .leading, spacing: 16) {
      EditorialRubric("Writing style")

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

      VStack(alignment: .leading, spacing: 8) {
        Text("Signature phrases")
          .font(WingmanEditorial.body(13, .medium))
          .foregroundStyle(WingmanEditorial.inkSecondary)
        ChipListField(
          placeholder: "sounds good, no worries at all",
          values: $model.state.writingStyle.signaturePhrases
        )
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Avoid")
          .font(WingmanEditorial.body(13, .medium))
          .foregroundStyle(WingmanEditorial.inkSecondary)
        ChipListField(
          placeholder: "exclamation points, corporate phrasing",
          values: $model.state.writingStyle.thingsToAvoid
        )
      }

      Button {
        model.save()
      } label: {
        Text("Save style")
      }
      .buttonStyle(.editorialSecondary)
      .padding(.top, 2)
    }
    .editorialCard(padding: 20)
  }

  private var memoriesSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      EditorialRubric("Memories")

      HStack(spacing: 10) {
        WingmanTextField("Add something worth remembering", text: $newMemoryText)

        Button {
          model.addMemory(newMemoryText)
          newMemoryText = ""
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.editorialCircle(size: 34))
        .disabled(newMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(newMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        .accessibilityLabel("Add memory")
      }

      if model.state.memories.isEmpty {
        Text("Nothing yet. Add facts worth remembering, or import a graph built from your Mac Messages history below.")
          .font(WingmanEditorial.body(14))
          .foregroundStyle(WingmanEditorial.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.vertical, 6)
      } else {
        VStack(spacing: 0) {
          ForEach(
            Array(model.state.memories.sorted(by: { $0.createdAt > $1.createdAt }).enumerated()),
            id: \.element.id
          ) { index, memory in
            if index > 0 { EditorialDivider() }
            MemoryRow(memory: memory) {
              model.removeMemory(id: memory.id)
            }
          }
        }
      }
    }
    .editorialCard(padding: 20)
  }

  private var importSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      EditorialRubric("On-device graph")

      Text("`wingman-history build-graph` on your Mac turns the watch log into a JSON file of deterministic, frequency-based facts — no automatic sync yet, so bring the file over yourself (AirDrop, Files, iCloud Drive) and import it here. Re-importing replaces the previous Mac-derived memories without touching the ones you wrote yourself.")
        .font(WingmanEditorial.body(13))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      Button {
        isImporting = true
      } label: {
        Label("Import Mac graph…", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(.editorialSecondary)
      .padding(.top, 2)
    }
    .editorialCard(padding: 20)
  }
}

/// A remembered fact is something a human said about themselves, so it is set
/// in the serif like every other piece of written content in the app.
private struct MemoryRow: View {
  let memory: MemoryFact
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(memory.text)
        .font(WingmanEditorial.answer(16))
        .foregroundStyle(WingmanEditorial.ink)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)

      if let badge = memory.source.badgeLabel {
        Text(badge)
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(WingmanEditorial.inkSecondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .overlay(Capsule().stroke(WingmanEditorial.hairline, lineWidth: 1))
      }

      if memory.source.allowsManualRemoval {
        Button(action: onDelete) {
          Image(systemName: "xmark")
            .font(.system(size: 11))
            .foregroundStyle(WingmanEditorial.inkSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove memory")
      }
    }
    .padding(.vertical, 12)
  }
}
