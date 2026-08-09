import SwiftUI

/// The multiline sibling of `WingmanTextField` — same borderless, floating-
/// label treatment, but defaulting to an auto-growing multi-line block for
/// longer free text (incoming messages, bios, style notes). Built on
/// `TextField(axis: .vertical)` rather than `TextEditor`, since only the
/// former supports a native placeholder and grows with content out of the box.
public struct WingmanTextEditor: View {
  private var label: String
  @Binding private var text: String
  private var lineLimit: ClosedRange<Int>

  public init(_ label: String, text: Binding<String>, lineLimit: ClosedRange<Int> = 3...8) {
    self.label = label
    self._text = text
    self.lineLimit = lineLimit
  }

  public var body: some View {
    WingmanTextField(label, text: $text, axis: .vertical, lineLimit: lineLimit)
  }
}
