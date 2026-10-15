import UIKit

/// Direct reference-grid frames retain reusable controls without per-key constraints.
final class KeyboardRow: UIView {
    let kind: NativeKeyboardGeometry.Row
    private var buttons: [UIButton] = []
    private var geometry = NativeKeyboardGeometry(width: 0, compact: false)
    private var horizontalOffset: CGFloat = 0

    init(buttons: [UIButton], kind: NativeKeyboardGeometry.Row) {
        self.kind = kind
        super.init(frame: .zero)
        setButtons(buttons)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setButtons(_ buttons: [UIButton]) {
        for old in self.buttons where !buttons.contains(where: { $0 === old }) { old.removeFromSuperview() }
        self.buttons = buttons
        for button in buttons where button.superview !== self { addSubview(button) }
        setNeedsLayout()
    }

    func apply(_ geometry: NativeKeyboardGeometry, horizontalOffset: CGFloat = 0) {
        self.geometry = geometry
        self.horizontalOffset = horizontalOffset
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = geometry.frames(for: kind, count: buttons.count).map { $0.offsetBy(dx: horizontalOffset, dy: 0) }
        let vertical = geometry.trackingInsets(for: kind)
        for (index, button) in buttons.enumerated() {
            button.frame = frames[index]
            (button as? KeyboardButton)?.applyTypography(compact: geometry.compact,
                large: geometry.compact ? geometry.width >= 900 : geometry.width > 414)
            let left = index == 0 ? 0 : (frames[index - 1].maxX + frames[index].minX) / 2
            let right = index == buttons.count - 1 ? bounds.width : (frames[index].maxX + frames[index + 1].minX) / 2
            (button as? KeyboardButton)?.touchInsets = UIEdgeInsets(top: vertical.top,
                left: button.frame.minX - left, bottom: vertical.bottom, right: right - button.frame.maxX)
        }

    }

    func nearestButton(to point: CGPoint) -> UIButton? {
        var nearest: UIButton?
        var distance = CGFloat.greatestFiniteMagnitude
        for button in buttons where button.isEnabled && button.isUserInteractionEnabled && !button.isHidden {
            let value = max(button.frame.minX - point.x, point.x - button.frame.maxX, 0)
            if value < distance { distance = value; nearest = button }
        }
        return nearest
    }
}

