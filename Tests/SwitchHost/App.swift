import UIKit

/// Test-only host; never embedded in the shipping keyboard application.
@main final class SwitchHostApp: UIResponder, UIApplicationDelegate {
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
        view.addSubview(editor)
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
    }
}
