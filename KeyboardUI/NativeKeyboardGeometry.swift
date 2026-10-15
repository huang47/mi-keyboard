import UIKit

/// Visible caps measured on the iOS 26.5 English keyboard. Tracking gutters stay separate.
struct NativeKeyboardGeometry {
    enum Row: Int { case numbers, letters, home, lower, bottom }
    let width: CGFloat
    let compact: Bool
    var scale: CGFloat = 3
    private struct Reference {
        let width: CGFloat
        let pitch: CGFloat
        let capHeight: CGFloat
        let top: [(CGFloat, CGFloat)]
        let home: [(CGFloat, CGFloat)]
        let sides: [(CGFloat, CGFloat)]
        let bottom: [(CGFloat, CGFloat)]
    }

    private static let phone = Reference(width: 402, pitch: 54, capHeight: 43,
        top: [(6.666666667, 33.33333333), (46, 33.66666667), (85.66666667, 33.33333333), (125, 33.66666667), (164.6666667, 33.33333333), (204, 33.66666667), (243.6666667, 33.33333333), (283, 33.66666667), (322.6666667, 33.33333333), (362, 33.66666667)],
        home: [(26.33333333, 33.33333333), (65.66666667, 33.66666667), (105.3333333, 33.33333333), (144.6666667, 33.66666667), (184.3333333, 33.33333333), (223.6666667, 33.66666667), (263.3333333, 33.33333333), (302.6666667, 33.66666667), (342.3333333, 33.33333333)],
        sides: [(6.666666667, 45.33333333), (350, 45.66666667)],
        bottom: [(6.666666667, 43.33333333), (56, 43.33333333), (105.3333333, 191.3333333), (302.6666667, 93)])

    private static let largePhone = Reference(width: 440, pitch: 56, capHeight: 45,
        top: [(6.666666667, 37), (49.66666667, 37.33333333), (93, 37.33333333), (136.3333333, 37.33333333), (179.6666667, 37.33333333), (223, 37.33333333), (266.3333333, 37.33333333), (309.6666667, 37.33333333), (353, 37.33333333), (396.3333333, 37.33333333)],
        home: [(28, 37.33333333), (71.33333333, 37.33333333), (114.6666667, 37.33333333), (158, 37.33333333), (201.3333333, 37.33333333), (244.6666667, 37.33333333), (288, 37.33333333), (331.3333333, 37.33333333), (374.6666667, 37.33333333)],
        sides: [(6.666666667, 50), (383.3333333, 50.33333333)],
        bottom: [(6.666666667, 48), (60.66666667, 48), (114.6666667, 210.6666667), (331.3333333, 102.3333333)])

    private static let landscape = Reference(width: 874, pitch: 35.33333333, capHeight: 27.33333333,
        top: [(79, 66.33333333), (151.3333333, 66), (223.3333333, 66.33333333), (295.6666667, 66), (367.6666667, 66.33333333), (440, 66.33333333), (512.3333333, 66), (584.3333333, 66.33333333), (656.6666667, 66), (728.6666667, 66.33333333)],
        home: [(115, 66.33333333), (187.3333333, 66.33333333), (259.6666667, 66), (331.6666667, 66.33333333), (404, 66), (476, 66.33333333), (548.3333333, 66.33333333), (620.6666667, 66), (692.6666667, 66.33333333)],
        sides: [(79, 88), (707, 88)],
        bottom: [(79, 66.33333333), (151.3333333, 66), (223.3333333, 427.3333333), (656.6666667, 138.3333333)])

    private static let largeLandscape = Reference(width: 956, pitch: 35.33333333, capHeight: 27.33333333,
        top: [(121, 66), (193, 66), (265, 66), (337, 66), (409, 66), (481, 66), (553, 66), (625, 66), (697, 66), (769, 66)],
        home: [(157, 66), (229, 66), (301, 66), (373, 66), (445, 66), (517, 66), (589, 66), (661, 66), (733, 66)],
        sides: [(121, 87.66666667), (747.3333333, 87.66666667)],
        bottom: [(121, 66), (193, 66), (265, 426), (697, 138)])

    private var reference: Reference {
        compact ? (width >= 900 ? Self.largeLandscape : Self.landscape)
                : (width > 414 ? Self.largePhone : Self.phone)
    }
    var fieldHeight: CGFloat { reference.pitch * 5 + (compact ? 4 - 1 / 3 : (width > 414 ? 2 : 0)) }
    func height(of row: Row) -> CGFloat { reference.capHeight - (compact && row == .lower ? 1 / 3 : 0) }
    func spacing(after row: Row) -> CGFloat { compact ? 8 : 11 }
    func origin(of row: Row) -> CGFloat { 8 + CGFloat(row.rawValue) * reference.pitch - (compact && row == .bottom ? 1 / 3 : 0) }
    func trackingInsets(for row: Row) -> (top: CGFloat, bottom: CGFloat) {
        (row == .numbers ? 8 : spacing(after: row) / 2, row == .bottom ? spacing(after: row) : spacing(after: row) / 2)
    }
    private func snap(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
    func frames(for row: Row, count: Int) -> [CGRect] {
        let ref = reference
        let inset: CGFloat = compact ? ref.top[0].0 : 20 / 3
        let factor = compact ? min(1, width / ref.width) : max(0, width - 2 * inset) / (ref.width - 2 * inset)
        let translation: CGFloat = compact ? (width - ref.width * factor) / 2 : inset * (1 - factor)
        func frame(_ pair: (CGFloat, CGFloat)) -> CGRect {
            let left = snap(pair.0 * factor + translation)
            let right = snap((pair.0 + pair.1) * factor + translation)
            let top = snap(origin(of: row))
            let bottom = snap(origin(of: row) + height(of: row))
            return CGRect(x: left, y: 0, width: right - left, height: bottom - top)
        }
        if row == .bottom { return ref.bottom.map(frame) }
        if row == .numbers || row == .letters, count == 10 { return ref.top.map(frame) }
        if row == .home, count == 9 { return ref.home.map(frame) }
        if row == .lower, count == 9 {
            return [frame(ref.sides[0])] + ref.home[1...7].map(frame) + [frame(ref.sides[1])]
        }
        let sideKeys = row == .lower
        let ordinaryCount = count - (sideKeys ? 2 : 0)
        let step = ref.top[1].0 - ref.top[0].0
        let start = ref.top[0].0 + CGFloat(10 - ordinaryCount) * step / 2
        var result = (0..<ordinaryCount).map { frame((start + CGFloat($0) * step, ref.top[0].1)) }
        if sideKeys { result.insert(frame(ref.sides[0]), at: 0); result.append(frame(ref.sides[1])) }
        return result
    }
}
