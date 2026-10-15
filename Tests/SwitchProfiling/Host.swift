import UIKit
import os

/// Test-only host; never embedded in the shipping keyboard application.
final class SwitchHostApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = SwitchHostController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

private final class SwitchHostController: UIViewController {
    private let editor = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        editor.accessibilityIdentifier = "switch-editor"
        editor.borderStyle = .roundedRect
        editor.autocorrectionType = .no
        editor.autocapitalizationType = .none
        editor.spellCheckingType = .no
        editor.translatesAutoresizingMaskIntoConstraints = false
        editor.addTarget(self, action: #selector(editorChanged), for: .editingChanged)
        view.addSubview(editor)
        let marker = UIButton(type: .system)
        marker.frame = CGRect(x: 24, y: 230, width: 180, height: 44)
        marker.setTitle("Arm cold capture", for: .normal)
        marker.accessibilityIdentifier = "cold-marker"
        marker.addAction(UIAction { _ in hostProfile("cold.ready") }, for: .touchUpInside)
        view.addSubview(marker)
        view.addSubview(ProfileClock(frame: CGRect(x: 24, y: 190, width: 272, height: 16)))
        for (event, notification) in [("inputModeChanged", UITextInputMode.currentInputModeDidChangeNotification), ("keyboardWillChangeFrame", UIResponder.keyboardWillChangeFrameNotification), ("keyboardDidChangeFrame", UIResponder.keyboardDidChangeFrameNotification)] {
            NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] note in
                hostProfile(event, "language=\(self?.editor.textInputMode?.primaryLanguage ?? "nil") animation=\(note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] ?? "nil")")
            }
        }
        NSLayoutConstraint.activate([
            editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            editor.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            editor.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            editor.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        editor.becomeFirstResponder()
        hostProfile("host.ready")
    }
    @objc private func editorChanged() {
        hostProfile("editor.changed", "value=\(editor.text ?? "")")
    }
}

// SWFULL: profiling host only; binary clock provides video frame alignment.
private let profileLog = Logger(subsystem: "com.shh.mi.switchprofile", category: "host")
private func hostProfile(_ event: String, _ details: String = "") {
    profileLog.notice("SWFULL t=\(ProcessInfo.processInfo.systemUptime, privacy: .public) event=\(event, privacy: .public) \(details, privacy: .public)")
}
final class ProfileApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        for touch in event.allTouches ?? [] where touch.phase == .began || touch.phase == .ended || touch.phase == .cancelled {
            hostProfile("host.touch", "touch=\(touch.timestamp) phase=\(touch.phase.rawValue) x=\(touch.location(in: touch.window).x) y=\(touch.location(in: touch.window).y)")
        }
        super.sendEvent(event)
    }
}
final class ProfileClock: UIView {
    private var bits: [CALayer] = []
    private var link: CADisplayLink?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .red
        for n in 0..<32 {
            let bit = CALayer(); bit.frame = CGRect(x: 16 + n * 8, y: 0, width: 8, height: 16)
            layer.addSublayer(bit); bits.append(bit)
        }
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tick() {
        let value = UInt32(truncatingIfNeeded: Int64(ProcessInfo.processInfo.systemUptime * 1000))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (n, bit) in bits.enumerated() { bit.backgroundColor = value & (1 << n) != 0 ? UIColor.white.cgColor : UIColor.black.cgColor }
        CATransaction.commit()
    }
}

@main @MainActor enum ProfileMain {
    static func main() {
        UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, NSStringFromClass(ProfileApplication.self), NSStringFromClass(SwitchHostApp.self))
    }
}
