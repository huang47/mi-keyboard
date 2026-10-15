import UIKit

// Profiling lower-bound control only. Not a functional Mi keyboard and never shipped.
final class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        switchProfile("viewDidLoad.begin")
        super.viewDidLoad()
        view.backgroundColor = .systemBlue
        let height = view.heightAnchor.constraint(equalToConstant: 310)
        height.priority = .init(999); height.isActive = true
        let label = UILabel(frame: CGRect(x: 20, y: 70, width: 320, height: 80))
        label.text = "Profiling lower-bound control"; label.textColor = .white
        view.addSubview(label)
        let globe = UIButton(type: .system)
        globe.translatesAutoresizingMaskIntoConstraints = false
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.tintColor = .white
        globe.addTarget(self, action: #selector(globeEvent(_:event:)), for: .allTouchEvents)
        view.addSubview(globe)
        NSLayoutConstraint.activate([globe.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 56), globe.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24), globe.widthAnchor.constraint(equalToConstant: 44), globe.heightAnchor.constraint(equalToConstant: 44)])
        switchProfile("viewDidLoad.end")
    }
    @objc private func globeEvent(_ sender: UIButton, event: UIEvent) {
        let touch = event.allTouches?.first
        switchProfile("globe.begin", "touch=\(touch?.timestamp ?? -1) phase=\(touch?.phase.rawValue ?? -1)")
        handleInputModeList(from: sender, with: event)
        switchProfile("globe.handler.return")
    }
    override func viewWillAppear(_ animated: Bool) {
        switchProfile("viewWillAppear.begin"); super.viewWillAppear(animated); switchProfile("viewWillAppear.end")
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); switchProfile("viewDidAppear") }
    override func viewWillDisappear(_ animated: Bool) {
        switchProfile("viewWillDisappear.begin"); super.viewWillDisappear(animated); switchProfile("viewWillDisappear.end")
    }
}
