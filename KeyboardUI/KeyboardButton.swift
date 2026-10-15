import UIKit

/// Reusable key with cached captions and immediate press feedback.
final class KeyboardButton: UIButton {
    private let surface = CAGradientLayer()
    private let caption = UILabel()
    private var alternateCaption: UILabel?
    private var keyboardTitle: String?
    private var compactTypography = false
    private var largeTypography = false
    override var accessibilityLabel: String? {
        get { super.accessibilityLabel ?? keyboardTitle }
        set { super.accessibilityLabel = newValue }
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        guard state == .normal else { super.setTitle(title, for: state); return }
        guard keyboardTitle != title else { return }
        keyboardTitle = title
        if caption.text == nil || caption.text == title {
            caption.text = title
            caption.isHidden = false
            alternateCaption?.isHidden = true
        } else {
            let alternate: UILabel
            if let cached = alternateCaption { alternate = cached }
            else {
                alternate = UILabel()
                configureCaption(alternate)
                alternate.textColor = caption.textColor
                alternateCaption = alternate
            }
            if alternate.text != title { alternate.text = title }
            caption.isHidden = true
            alternate.isHidden = false
        }
        updateCaptionFonts()
        updateCaptionFrames()
    }

    override func title(for state: UIControl.State) -> String? {
        state == .normal ? keyboardTitle : super.title(for: state)
    }

    override func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        super.setTitleColor(color, for: state)
        if state == .normal { caption.textColor = color; alternateCaption?.textColor = color }
    }

    var input = ""
    var onHighlightChange: ((KeyboardButton) -> Void)?
    var touchInsets = UIEdgeInsets(top: 7, left: 4, bottom: 7, right: 4)

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Build the alternate caption only on first use, then cache both cases.
        configureCaption(caption)
        surface.colors = [UIColor.white.cgColor, UIColor.white.cgColor]
        // A key press must change color in this event, not start a default opacity animation.
        surface.actions = ["opacity": NSNull(), "colors": NSNull()]
        surface.cornerRadius = 8
        surface.borderWidth = 0
        surface.borderColor = UIColor(white: 0.5, alpha: 1).cgColor
        layer.insertSublayer(surface, at: 0)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: KeyboardButton, _: UITraitCollection) in
            button.applyTypography(compact: button.compactTypography)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Captions own their fonts; avoid creating an unused UIKit title label.
    func configureAppearance() {
        updateCaptionFonts()
        setTitleColor(.label, for: .normal)
        tintColor = .label
        backgroundColor = .clear
    }

    func applyTypography(compact: Bool, large: Bool? = nil) {
        let large = large ?? largeTypography
        if compactTypography != compact || largeTypography != large {
            compactTypography = compact
            largeTypography = large
            updateCaptionFonts()
            updateCaptionFrames()
        }
        let color = traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.33, alpha: 1) : .white
        let colors = [color.cgColor, color.cgColor]
        if surface.colors as? [CGColor] != colors { surface.colors = colors }
    }

    private func configureCaption(_ label: UILabel) {
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        addSubview(label)
    }

    private func updateCaptionFonts() {
        updateCaptionFont(caption)
        if let alternateCaption { updateCaptionFont(alternateCaption) }
    }

    private func updateCaptionFont(_ label: UILabel) {
        let font = NativeKeyboardTypography.font(for: label.text, compact: compactTypography)
        if label.font != font { label.font = font }
    }

    private func updateCaptionFrames() {
        updateCaptionFrame(caption)
        if let alternateCaption { updateCaptionFrame(alternateCaption) }
    }

    private func updateCaptionFrame(_ label: UILabel) {
        let offset = NativeKeyboardTypography.offset(for: label.text, compact: compactTypography, large: largeTypography)
        let center = CGPoint(x: bounds.midX + offset.x, y: bounds.midY + offset.y)
        if label.bounds.size != bounds.size { label.bounds = bounds }
        if label.center != center { label.center = center }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCaptionFrames()
        imageView?.layer.removeAnimation(forKey: "opacity")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // UIButton can insert its image view below existing layers when the image changes.
        layer.insertSublayer(surface, at: 0)
        surface.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
        CATransaction.commit()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: -touchInsets.top, left: -touchInsets.left,
                                     bottom: -touchInsets.bottom, right: -touchInsets.right)).contains(point)
    }

    override var isHighlighted: Bool {
        didSet {
            surface.opacity = isHighlighted ? 0.75 : 1
            if isHighlighted != oldValue { onHighlightChange?(self) }
        }
    }
}

