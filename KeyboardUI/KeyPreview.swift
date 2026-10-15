import UIKit

/// One reusable, non-interactive popover stays inside the extension's bounds.
final class KeyPreview: UIView {
    private let shape = CAShapeLayer()
    private let caption = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityIdentifier = "key-preview"
        shape.fillColor = UIColor(white: 0.88, alpha: 1).cgColor
        shape.strokeColor = UIColor(white: 0.45, alpha: 1).cgColor
        shape.lineWidth = 0.5
        layer.addSublayer(shape)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 2)
        caption.font = .systemFont(ofSize: 32)
        caption.textColor = UIColor(white: 0.12, alpha: 1)
        caption.textAlignment = .center
        caption.isAccessibilityElement = false
        caption.accessibilityIdentifier = "key-preview-character"
        addSubview(caption)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(title: String, keyFrame: CGRect, width: CGFloat) {
        let bubbleWidth = min(width - 4, max(48, keyFrame.width + 16))
        let x = max(2, min(width - bubbleWidth - 2, keyFrame.midX - bubbleWidth / 2))
        let y = max(0, keyFrame.minY - 54)
        let headHeight = keyFrame.minY - y - 4
        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            frame = CGRect(x: x, y: y, width: bubbleWidth, height: keyFrame.maxY - y)
            let left = keyFrame.minX - x
            let right = keyFrame.maxX - x
            let neck = keyFrame.minY - y + 5
            let bottom = bounds.height
            let w = bubbleWidth
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: w - 8, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 8), controlPoint: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: headHeight - 8))
            path.addQuadCurve(to: CGPoint(x: w - 5, y: headHeight), controlPoint: CGPoint(x: w, y: headHeight))
            path.addLine(to: CGPoint(x: right, y: neck))
            path.addLine(to: CGPoint(x: right, y: bottom - 5))
            path.addQuadCurve(to: CGPoint(x: right - 5, y: bottom), controlPoint: CGPoint(x: right, y: bottom))
            path.addLine(to: CGPoint(x: left + 5, y: bottom))
            path.addQuadCurve(to: CGPoint(x: left, y: bottom - 5), controlPoint: CGPoint(x: left, y: bottom))
            path.addLine(to: CGPoint(x: left, y: neck))
            path.addLine(to: CGPoint(x: 5, y: headHeight))
            path.addQuadCurve(to: CGPoint(x: 0, y: headHeight - 8), controlPoint: CGPoint(x: 0, y: headHeight))
            path.addLine(to: CGPoint(x: 0, y: 8))
            path.addQuadCurve(to: CGPoint(x: 8, y: 0), controlPoint: CGPoint(x: 0, y: 0))
            path.close()
            shape.frame = bounds
            shape.path = path.cgPath
            layer.shadowPath = path.cgPath
            caption.frame = CGRect(x: 0, y: 0, width: w, height: headHeight)
            caption.text = title
            isHidden = false
            CATransaction.commit()
        }
    }
}

