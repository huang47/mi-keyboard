import UIKit

/// Exact frames avoid UICollectionView's estimated-size correction passes while typing.
final class CandidateListLayout: UICollectionViewLayout {
    private var starts: [CGFloat] = []
    private var widths: [CGFloat] = []
    private var contentWidth: CGFloat = 0
    private struct Frames {
        let words: [String]
        let starts: [CGFloat]
        let widths: [CGFloat]
        let contentWidth: CGFloat
    }
    // At most 16 dictionary prefixes / 4,096 measured candidates (64 KiB of
    // coordinate buffers). No input history or cache is persisted.
    private var cachedFrames: [String: Frames] = [:]
    private var cacheOrder: [String] = []
    private var cachedCandidateCount = 0

    func clearCache() {
        cachedFrames.removeAll(keepingCapacity: true)
        cacheOrder.removeAll(keepingCapacity: true)
        cachedCandidateCount = 0
    }

    var rowHeight: CGFloat = 32 {
        didSet { if rowHeight != oldValue { invalidateLayout() } }
    }

    func setWords(_ words: [String], forCode code: String? = nil) {
        if let code, let cached = cachedFrames[code], cached.words == words {
            starts = cached.starts
            widths = cached.widths
            contentWidth = cached.contentWidth
            invalidateLayout()
            return
        }
        starts.removeAll(keepingCapacity: true)
        widths.removeAll(keepingCapacity: true)
        starts.reserveCapacity(words.count)
        widths.reserveCapacity(words.count)
        var cursor: CGFloat = 0
        for word in words {
            let width = CandidateListCell.width(for: word)
            starts.append(cursor)
            widths.append(width)
            cursor += width + 4
        }
        contentWidth = max(0, cursor - 4)
        if let code, !words.isEmpty, words.count <= 4096 {
            if let previous = cachedFrames.removeValue(forKey: code) {
                cachedCandidateCount -= previous.words.count
                cacheOrder.removeAll { $0 == code }
            }
            while cachedCandidateCount + words.count > 4096 || cacheOrder.count >= 16 {
                let oldest = cacheOrder.removeFirst()
                cachedCandidateCount -= cachedFrames.removeValue(forKey: oldest)!.words.count
            }
            cachedFrames[code] = Frames(words: words, starts: starts, widths: widths, contentWidth: contentWidth)
            cacheOrder.append(code)
            cachedCandidateCount += words.count
        }
        invalidateLayout()
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: max(contentWidth, collectionView?.bounds.width ?? 0), height: rowHeight)
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0, widths.indices.contains(indexPath.item) else { return nil }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(x: starts[indexPath.item], y: 0, width: widths[indexPath.item], height: rowHeight)
        return attributes
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard rect.maxY > 0, rect.minY < rowHeight else { return [] }
        var lower = 0
        var upper = widths.count
        while lower < upper {
            let mid = (lower + upper) / 2
            if starts[mid] + widths[mid] < rect.minX { lower = mid + 1 }
            else { upper = mid }
        }
        var result: [UICollectionViewLayoutAttributes] = []
        while lower < widths.count && starts[lower] < rect.maxX {
            if let item = layoutAttributesForItem(at: IndexPath(item: lower, section: 0)) { result.append(item) }
            lower += 1
        }
        return result
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size != newBounds.size
    }
}

final class CandidateListCell: UICollectionViewCell {
    static let font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    private static let asciiAdvance = ("M" as NSString).size(withAttributes: [.font: font]).width
    private let button = UIButton(type: .system)
    private let label = UILabel()
    var onChoose: ((Int) -> Void)?

    private static let hanAdvance = ("字" as NSString).size(withAttributes: [.font: font]).width
    private static var mixedSpacing: [UInt32: (beforeHan: CGFloat, afterHan: CGFloat)] = [:]

    private static func spacing(for scalar: Unicode.Scalar) -> (beforeHan: CGFloat, afterHan: CGFloat) {
        if let cached = mixedSpacing[scalar.value] { return cached }
        let text = String(scalar)
        let before = ((text + "字") as NSString).size(withAttributes: [.font: font]).width - asciiAdvance - hanAdvance
        let after = (("字" + text) as NSString).size(withAttributes: [.font: font]).width - asciiAdvance - hanAdvance
        let value = (beforeHan: before, afterHan: after)
        mixedSpacing[scalar.value] = value
        return value
    }

    static func width(for word: String) -> CGFloat {
        func shapedWidth() -> CGFloat {
            max(44, ceil((word as NSString).size(withAttributes: [.font: font]).width) + 28)
        }
        var width: CGFloat = 0
        var previousASCII: Unicode.Scalar?
        var previousHan = false
        var hasHan = false
        var hasOtherASCII = false
        for scalar in word.unicodeScalars {
            switch scalar.value {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
                width += asciiAdvance
                if previousHan { width += spacing(for: scalar).afterHan }
                previousASCII = scalar
                previousHan = false
            case 0x20...0x7E:
                if hasHan { return shapedWidth() }
                width += asciiAdvance
                hasOtherASCII = true
                previousASCII = nil
                previousHan = false
            case 0x3400...0x4DBF, 0x4E00...0x9FFF:
                if hasOtherASCII { return shapedWidth() }
                width += hanAdvance
                if let previousASCII { width += spacing(for: previousASCII).beforeHan }
                previousASCII = nil
                previousHan = true
                hasHan = true
            default:
                // Combining marks, emoji, punctuation and other scripts need font shaping.
                return shapedWidth()
            }
        }
        return max(44, ceil(width) + 28)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        button.backgroundColor = UIColor(white: 0.8, alpha: 1)
        button.layer.cornerRadius = 5
        label.font = Self.font
        label.lineBreakMode = .byClipping
        label.textAlignment = .center
        label.textColor = UIColor(white: 0.12, alpha: 1)
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        label.accessibilityIdentifier = "candidate-text"
        button.addSubview(label)
        contentView.addSubview(button)
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onChoose?(self.button.tag)
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = contentView.bounds
        label.frame = button.bounds
    }

    func configure(word: String, index: Int) {
        button.tag = index
        label.text = word
        button.accessibilityIdentifier = "candidate-\(index)"
        button.accessibilityLabel = "候選 \(index + 1)，\(word)"
    }
}
