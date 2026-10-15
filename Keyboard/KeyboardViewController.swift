import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()
    private var height: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.topAnchor.constraint(equalTo: view.topAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        keyboard.onOutput = { [weak self] output in
            guard let self else { return }
            switch output {
            case .insert(let text): self.textDocumentProxy.insertText(text)
            case .deleteBackward: self.textDocumentProxy.deleteBackward()
            case .none: break
            }
        }
        // The spacebar globe is always usable, including devices with a system globe below.
        keyboard.onGlobe = { [weak self] sender, event in
            self?.keyboard.clearComposition()
            self?.handleInputModeList(from: sender, with: event)
        }
        height = view.heightAnchor.constraint(equalToConstant: KeyboardView.preferredHeight(width: view.bounds.width, compact: false))
        height?.priority = .init(999)
        height?.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboard.load(table: try? TableStore.bundled())
    }

    override func viewWillDisappear(_ animated: Bool) {
        keyboard.clearComposition()
        super.viewWillDisappear(animated)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeight()
    }

    private func updateHeight() {
        height?.constant = KeyboardView.preferredHeight(width: view.bounds.width, compact: traitCollection.verticalSizeClass == .compact)
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        keyboard.clearComposition()
    }
}
