import UIKit

/// Cached public system fonts calibrated to the native keyboard glyph bounds.
enum NativeKeyboardTypography {
    private struct Glyph { let font: UIFont; var offset: CGPoint = .zero }
    private static let letters = Array("qwertyuiopasdfghjklzxcvbnm")
    private static func calibrated(_ size: CGFloat, _ ratios: [(CGFloat, CGFloat)]) -> [Character: Glyph] {
        let descriptor = UIFont.systemFont(ofSize: size, weight: .regular).fontDescriptor
        return Dictionary(uniqueKeysWithValues: zip(letters, ratios).map { character, ratio in
            (character, Glyph(font: UIFont(descriptor: descriptor.withMatrix(CGAffineTransform(scaleX: ratio.0, y: ratio.1)), size: size)))
        })
    }

    private static let upper = calibrated(22, [
        (0.880952381, 1), (0.9649122807, 1), (0.9310344828, 1), (0.9411764706, 1), (0.9166666667, 1), (0.9473684211, 1), (0.9459459459, 1), (1, 1), (0.880952381, 1), (0.96875, 0.9787234043), (1, 0.9787234043), (1, 1), (0.9210526316, 1), (0.9642857143, 1), (0.875, 1), (0.9459459459, 1), (0.962962963, 1), (0.9428571429, 1), (0.9642857143, 1), (0.9411764706, 1), (0.972972973, 1), (0.8974358974, 1), (1, 1), (0.9411764706, 0.9787234043), (0.9189189189, 1), (0.9130434783, 1)
    ])

    private static let lower = calibrated(25, [
        (0.9705882353, 1), (1, 1), (0.9393939394, 0.975), (1, 1), (1.052631579, 0.9795918367), (0.9714285714, 1), (0.96875, 0.9743589744), (1, 0.9811320755), (0.9428571429, 0.975), (0.9142857143, 1), (0.9677419355, 0.975), (1, 1), (0.9705882353, 0.9814814815), (1, 0.9814814815), (0.9411764706, 1.019230769), (0.96875, 1), (1.071428571, 0.9848484848), (0.9677419355, 1), (1, 1), (1, 1), (1.03125, 1), (0.9090909091, 0.975), (0.9705882353, 1), (0.9142857143, 0.9814814815), (0.96875, 1), (0.9811320755, 1)
    ])

    private static let compactLower = calibrated(25, [
        (0.8235294118, 0.8653846154), (0.862745098, 0.8947368421), (0.8181818182, 0.85), (0.8421052632, 0.8717948718), (0.8947368421, 0.8571428571), (0.8571428571, 0.9019607843), (0.875, 0.8717948718), (0.875, 0.8490566038), (0.8, 0.85), (0.8, 0.8653846154), (0.8387096774, 0.85), (0.8666666667, 0.85), (0.8235294118, 0.8518518519), (0.85, 0.8703703704), (0.8235294118, 0.8846153846), (0.84375, 0.8679245283), (0.9285714286, 0.8636363636), (0.8387096774, 0.8679245283), (0.8333333333, 0.8679245283), (0.8928571429, 0.8947368421), (0.90625, 0.8947368421), (0.7878787879, 0.85), (0.8529411765, 0.8947368421), (0.8285714286, 0.8518518519), (0.84375, 0.8717948718), (0.8679245283, 0.8717948718)
    ])

    private static let compactUpper = calibrated(22, [
        (0.7619047619, 0.8653846154), (0.8421052632, 0.8695652174), (0.8275862069, 0.8695652174), (0.8235294118, 0.8695652174), (0.8055555556, 0.8695652174), (0.8421052632, 0.8695652174), (0.8378378378, 0.8723404255), (0.8333333333, 0.8695652174), (0.7619047619, 0.875), (0.84375, 0.8510638298), (0.8461538462, 0.8510638298), (0.8529411765, 0.875), (0.7894736842, 0.8695652174), (0.8214285714, 0.8695652174), (0.775, 0.875), (0.8108108108, 0.8695652174), (0.8518518519, 0.8723404255), (0.8285714286, 0.8695652174), (0.8214285714, 0.8695652174), (0.8235294118, 0.8695652174), (0.8648648649, 0.8695652174), (0.7948717949, 0.875), (0.8461538462, 0.8695652174), (0.8235294118, 0.8510638298), (0.8108108108, 0.8695652174), (0.8043478261, 0.8695652174)
    ])

    static func font(for title: String?, compact: Bool) -> UIFont {
        guard let title, title.count == 1, let character = title.lowercased().first, letters.contains(character) else {
            return compact ? compactControl : control
        }
        let lowercase = title == title.lowercased()
        return (lowercase ? (compact ? compactLower : lower) : (compact ? compactUpper : upper))[character]!.font
    }
    private static let upperOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: 0, y: -1.333333333), CGPoint(x: 0.3333333333, y: -1.333333333), CGPoint(x: 0.3333333333, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: 0, y: -1.333333333), CGPoint(x: 0, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: -0.1666666667, y: -1.333333333), CGPoint(x: 0.8333333333, y: -1.333333333), CGPoint(x: -0.5, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: -0.6666666667, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: 0, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: 0.6666666667, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: 0.3333333333, y: -1.333333333)
    ]))
    private static let lowerOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: 0.6666666667, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0.5, y: -2.666666667), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: 1, y: -2.666666667), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0.5, y: -2.666666667), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: 0.5, y: -2.666666667), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: -0.3333333333, y: -2.666666667), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0, y: -2.666666667), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: -0.1666666667, y: -2.5), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: -0.3333333333, y: -2), CGPoint(x: 0.8333333333, y: -2.333333333), CGPoint(x: 0, y: -2.333333333), CGPoint(x: 0.8333333333, y: -2.333333333), CGPoint(x: -0.3333333333, y: -2.333333333), CGPoint(x: 0.3333333333, y: -2.666666667), CGPoint(x: 0, y: -2.333333333), CGPoint(x: 0.5, y: -2.666666667), CGPoint(x: 0, y: -2.333333333), CGPoint(x: 0.8333333333, y: -2.333333333)
    ]))
    private static let compactLowerOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: 0.3333333333, y: -2), CGPoint(x: -0.3333333333, y: -2.333333333), CGPoint(x: 0, y: -2.166666667), CGPoint(x: 0.8333333333, y: -2), CGPoint(x: 0.5, y: -2), CGPoint(x: 0.3333333333, y: -2.333333333), CGPoint(x: -0.5, y: -2.166666667), CGPoint(x: -0.3333333333, y: -2), CGPoint(x: 0.6666666667, y: -2.166666667), CGPoint(x: 0.3333333333, y: -2), CGPoint(x: 0.1666666667, y: -2.5), CGPoint(x: -0.3333333333, y: -2.5), CGPoint(x: 0.5, y: -2.5), CGPoint(x: 0.8333333333, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: -0.5, y: -2), CGPoint(x: 0.6666666667, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0, y: -2.166666667), CGPoint(x: 0.3333333333, y: -2.166666667), CGPoint(x: 0.5, y: -2), CGPoint(x: 0, y: -2.166666667), CGPoint(x: 0.1666666667, y: -2), CGPoint(x: 0, y: -1.833333333), CGPoint(x: 0.5, y: -1.833333333)
    ]))
    private static let compactUpperOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: -0.1666666667, y: 0), CGPoint(x: -0.3333333333, y: -0.3333333333), CGPoint(x: -0.1666666667, y: -0.3333333333), CGPoint(x: 0.3333333333, y: -0.3333333333), CGPoint(x: 0.3333333333, y: -0.3333333333), CGPoint(x: 0, y: -0.3333333333), CGPoint(x: -0.3333333333, y: -0.3333333333), CGPoint(x: -0.1666666667, y: -0.3333333333), CGPoint(x: 0, y: -0.3333333333), CGPoint(x: 0.5, y: 0.3333333333), CGPoint(x: -0.5, y: 0), CGPoint(x: -0.8333333333, y: -0.6666666667), CGPoint(x: 0.3333333333, y: -0.6666666667), CGPoint(x: 0.5, y: -0.6666666667), CGPoint(x: 0, y: -0.6666666667), CGPoint(x: -0.1666666667, y: -0.6666666667), CGPoint(x: -0.3333333333, y: -0.6666666667), CGPoint(x: 0.3333333333, y: -0.6666666667), CGPoint(x: 0.5, y: -0.6666666667), CGPoint(x: -0.1666666667, y: -1.166666667), CGPoint(x: 0.5, y: -1.166666667), CGPoint(x: 0.5, y: -1.166666667), CGPoint(x: -0.3333333333, y: -1.166666667), CGPoint(x: -0.1666666667, y: -0.5), CGPoint(x: -0.5, y: -1.166666667), CGPoint(x: 0.3333333333, y: -1.166666667)
    ]))
    private static let largeUpperOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: 0, y: -1.333333333), CGPoint(x: 0.3333333333, y: -1.333333333), CGPoint(x: -0.1666666667, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: 0, y: -1.333333333), CGPoint(x: -0.6666666667, y: -1.333333333), CGPoint(x: 0.1666666667, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: -0.8333333333, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: 0.3333333333, y: -1.333333333), CGPoint(x: -0.5, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: -0.6666666667, y: -1.333333333), CGPoint(x: -2.664535259e-15, y: -1.333333333), CGPoint(x: 0.6666666667, y: -1.333333333), CGPoint(x: -0.5, y: -1.333333333), CGPoint(x: 0.3333333333, y: -1.333333333), CGPoint(x: 0.5, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: 0.6666666667, y: -1.333333333), CGPoint(x: -0.3333333333, y: -1.333333333), CGPoint(x: -0.1666666667, y: -1.333333333)
    ]))
    private static let largeLowerOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: 0.6666666667, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 8.881784197e-16, y: -2.666666667), CGPoint(x: 0, y: -2.333333333), CGPoint(x: 1, y: -2.666666667), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: -0.3333333333, y: -2.666666667), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: 0.5, y: -2.666666667), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: -0.3333333333, y: -2.666666667), CGPoint(x: -0.3333333333, y: -2.333333333), CGPoint(x: 0.6666666667, y: -2.666666667), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: -0.1666666667, y: -2.5), CGPoint(x: 0.5, y: -2.333333333), CGPoint(x: -0.3333333333, y: -2), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0.6666666667, y: -2.333333333), CGPoint(x: -1.443289932e-15, y: -2.333333333), CGPoint(x: 0.3333333333, y: -2.333333333), CGPoint(x: 0.3333333333, y: -2.666666667), CGPoint(x: 0, y: -2.333333333), CGPoint(x: 0.5, y: -2.666666667), CGPoint(x: 0, y: -2.333333333), CGPoint(x: -5.551115123e-16, y: -2.333333333)
    ]))
    private static let largeCompactLowerOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: 0.3333333333, y: -2), CGPoint(x: -0.3333333333, y: -2.333333333), CGPoint(x: 0, y: -2.166666667), CGPoint(x: 0.8333333333, y: -2), CGPoint(x: 0.5, y: -2), CGPoint(x: 0.3333333333, y: -2.333333333), CGPoint(x: -0.5, y: -2.166666667), CGPoint(x: 0.1666666667, y: -2), CGPoint(x: 0.6666666667, y: -2.166666667), CGPoint(x: -0.1666666667, y: -2), CGPoint(x: 0.1666666667, y: -2.5), CGPoint(x: 0.1666666667, y: -2.5), CGPoint(x: 0.5, y: -2.5), CGPoint(x: 0.3333333333, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 3.552713679e-15, y: -2), CGPoint(x: 0.6666666667, y: -2.333333333), CGPoint(x: 0.1666666667, y: -2.333333333), CGPoint(x: 0, y: -2.166666667), CGPoint(x: 0.3333333333, y: -2.166666667), CGPoint(x: 0.5, y: -2), CGPoint(x: 0, y: -2.166666667), CGPoint(x: 0.1666666667, y: -2), CGPoint(x: 0, y: -1.833333333), CGPoint(x: 0, y: -1.833333333)
    ]))
    private static let largeCompactUpperOffsets: [Character: CGPoint] = Dictionary(uniqueKeysWithValues: zip(letters, [
        CGPoint(x: -0.1666666667, y: 0), CGPoint(x: -0.3333333333, y: -0.3333333333), CGPoint(x: -0.1666666667, y: -0.3333333333), CGPoint(x: 0.3333333333, y: -0.3333333333), CGPoint(x: -0.1666666667, y: -0.3333333333), CGPoint(x: 0, y: -0.3333333333), CGPoint(x: -0.3333333333, y: -0.3333333333), CGPoint(x: -0.1666666667, y: -0.3333333333), CGPoint(x: 0, y: -0.3333333333), CGPoint(x: 0.5, y: 0.3333333333), CGPoint(x: -0.5, y: 0), CGPoint(x: -0.1666666667, y: -0.6666666667), CGPoint(x: 0.3333333333, y: -0.6666666667), CGPoint(x: -0.1666666667, y: -0.6666666667), CGPoint(x: 0, y: -0.6666666667), CGPoint(x: -0.1666666667, y: -0.6666666667), CGPoint(x: -0.3333333333, y: -0.6666666667), CGPoint(x: 0.3333333333, y: -0.6666666667), CGPoint(x: 0.5, y: -0.6666666667), CGPoint(x: -0.1666666667, y: -1.166666667), CGPoint(x: 0.5, y: -1.166666667), CGPoint(x: 0.5, y: -1.166666667), CGPoint(x: -0.3333333333, y: -1.166666667), CGPoint(x: -0.1666666667, y: -0.5), CGPoint(x: -0.5, y: -1.166666667), CGPoint(x: 0.3333333333, y: -1.166666667)
    ]))
    static func offset(for title: String?, compact: Bool, large: Bool = false) -> CGPoint {
        guard let title, title.count == 1, let character = title.lowercased().first else { return .zero }
        let lowercase = title == title.lowercased()
        if large {
            return (lowercase ? (compact ? largeCompactLowerOffsets : largeLowerOffsets)
                              : (compact ? largeCompactUpperOffsets : largeUpperOffsets))[character] ?? .zero
        }
        return (lowercase ? (compact ? compactLowerOffsets : lowerOffsets) : (compact ? compactUpperOffsets : upperOffsets))[character] ?? .zero
    }
    private static let control = UIFont.systemFont(ofSize: 22, weight: .regular)
    private static let compactControl = UIFont.systemFont(ofSize: 18, weight: .regular)
}
