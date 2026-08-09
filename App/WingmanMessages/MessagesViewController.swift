import Messages
import SwiftUI
import UIKit
import WingmanCore

final class MessagesViewController: MSMessagesAppViewController {
  private let model = MessagesExtensionModel()
  private var hostController: UIHostingController<MessagesRootView>?

  override func viewDidLoad() {
    super.viewDidLoad()
    installRootView()
  }

  override func willBecomeActive(with conversation: MSConversation) {
    super.willBecomeActive(with: conversation)
    model.reload()
    model.select(message: conversation.selectedMessage)
  }

  override func didSelect(_ message: MSMessage, conversation: MSConversation) {
    super.didSelect(message, conversation: conversation)
    model.select(message: message)
    requestPresentationStyle(.expanded)
  }

  override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
    super.willTransition(to: presentationStyle)
    model.presentationStyle = presentationStyle
  }

  private func installRootView() {
    let rootView = MessagesRootView(
      model: model,
      requestExpanded: { [weak self] in self?.requestPresentationStyle(.expanded) },
      insertText: { [weak self] text in self?.insert(text: text) },
      insertCard: { [weak self] in self?.insertIntroductionCard() }
    )
    let hostController = UIHostingController(rootView: rootView)
    addChild(hostController)
    hostController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hostController.view)
    NSLayoutConstraint.activate([
      hostController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    hostController.didMove(toParent: self)
    self.hostController = hostController
  }

  private func insert(text: String) {
    guard let conversation = activeConversation else {
      model.lastError = "Open Wingman from a Messages conversation first."
      return
    }
    conversation.insertText(text) { [weak self] error in
      DispatchQueue.main.async {
        if let error { self?.model.lastError = error.localizedDescription } else {
          self?.dismiss()
        }
      }
    }
  }

  private func insertIntroductionCard() {
    guard let conversation = activeConversation else {
      model.lastError = "Open Wingman from a Messages conversation first."
      return
    }
    do {
      let card = try model.makeIntroductionCard()
      let layout = MSMessageTemplateLayout()
      layout.caption = "Meet My Human"
      layout.subcaption = "\(card.firstName) × \(card.secondName)"
      layout.trailingCaption = card.relationshipLabel
      layout.imageTitle = "Possible resonance"
      layout.imageSubtitle = card.resonance

      let message = MSMessage()
      message.layout = layout
      message.url = try MessagePayloadCodec.encode(card)
      message.summaryText = "Wingman introduction for \(card.firstName) and \(card.secondName)"

      conversation.insert(message) { [weak self] error in
        DispatchQueue.main.async {
          if let error { self?.model.lastError = error.localizedDescription } else {
            self?.dismiss()
          }
        }
      }
    } catch {
      model.lastError = error.localizedDescription
    }
  }
}
