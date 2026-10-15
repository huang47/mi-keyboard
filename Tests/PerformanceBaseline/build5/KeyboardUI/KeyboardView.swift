import UIKit

final class KeyboardView: UIView, UICollectionViewDataSource {
    var engine = CompositionEngine()
    var onOutput: ((CompositionEngine.Output) -> Void)?
    var onGlobe: ((UIView, UIEvent) -> Void)?
    private let stack = UIStackView()
    private let codeButton = UIButton(type: .system)
    private let candidateArea = UIView()
    private let candidatePlaceholder = UILabel()
    private let candidateLayout = CandidateLayout()
    private lazy var candidateScroll = UICollectionView(frame: .zero, collectionViewLayout: candidateLayout)
    private var displayedCode = ""
    private var displayedCandidates: [String] = []
    private struct RenderState: Equatable {
        let code: String
        let mode: CompositionEngine.Mode
        let hint: String?
        let error: String?
        let hasTable: Bool
        let words: [String]
    }
    private var renderedState: RenderState?
    private let keys = UIStackView()
    private var candidateHeight: NSLayoutConstraint!
    private var candidateScrollHeight: NSLayoutConstraint!
    private var geometryWidth: CGFloat = -1
    private var geometryCompact: Bool?
    private static let numberSymbols = [".", ",", ":", "/", "@", "-", "!", "?", "'", "$"]

    static func preferredHeight(width: CGFloat, compact: Bool) -> CGFloat {
        12 + (compact ? 30 : 32) + 5 + IaccesGeometry(width: width, compact: compact).fieldHeight
    }
    private var showingComposition = true
    var isShowingComposition: Bool { showingComposition }
    private var symbols = false
    private var moreSymbols = false
    enum ShiftState: String { case off, once, locked
        var symbol: String {
            switch self {
            case .off: return "shift"
            case .once: return "shift.fill"
            case .locked: return "capslock.fill"
            }
        }
    }
    private(set) var shiftState: ShiftState = .off
    private var lastShiftTap: TimeInterval?
    private var repeatTimer: Timer?
    private weak var modeButton: UIButton?
    private weak var globeButton: UIButton?
    private weak var pageButton: UIButton?
    private weak var shiftButton: UIButton?
    private var letterButtons: [(UIButton, String)] = []
    private var numberKeys: UIView?
    private var bottomKeys: KeyRow?
    private var characterButtons: [[UIButton]] = [[], [], []]
    private var leftSideButton: UIButton?
    private var deleteButton: UIButton?
    private static let keyAction = UIAction.Identifier("keyboard-key")
    // When iOS supplies its own switch key, this icon belongs to the spacebar's touch area.
    var needsGlobe = true {
        didSet {
            globeButton?.isUserInteractionEnabled = needsGlobe
            globeButton?.isAccessibilityElement = needsGlobe
        }
    }
    var loadError: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.12, alpha: 1)
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        codeButton.titleLabel?.font = .monospacedSystemFont(ofSize: 17, weight: .semibold)
        codeButton.setTitleColor(UIColor(white: 0.9, alpha: 1), for: .normal)
        codeButton.contentHorizontalAlignment = .left
        codeButton.accessibilityIdentifier = "composition"
        codeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        codeButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(sendRaw(_:))))
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateHeight = candidateArea.heightAnchor.constraint(equalToConstant: 32)
        candidateHeight.priority = .init(999)
        candidateHeight.isActive = true
        candidateArea.clipsToBounds = true
        candidateScrollHeight = candidateScroll.heightAnchor.constraint(equalToConstant: 32)
        candidateScroll.backgroundColor = .clear
        candidateScroll.dataSource = self
        candidateScroll.register(CandidateCell.self, forCellWithReuseIdentifier: "candidate")
        candidateScroll.accessibilityIdentifier = "candidate-list"
        candidateScroll.translatesAutoresizingMaskIntoConstraints = false
        codeButton.translatesAutoresizingMaskIntoConstraints = false
        candidateArea.addSubview(codeButton)
        candidateArea.addSubview(candidateScroll)
        candidatePlaceholder.font = .systemFont(ofSize: 14)
        candidatePlaceholder.textColor = UIColor(white: 0.75, alpha: 1)
        candidatePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        candidateArea.addSubview(candidatePlaceholder)
        NSLayoutConstraint.activate([
            codeButton.leadingAnchor.constraint(equalTo: candidateArea.leadingAnchor, constant: 4),
            codeButton.widthAnchor.constraint(equalToConstant: 60),
            codeButton.topAnchor.constraint(equalTo: candidateArea.topAnchor),
            codeButton.bottomAnchor.constraint(equalTo: candidateArea.bottomAnchor),
            candidateScroll.leadingAnchor.constraint(equalTo: codeButton.trailingAnchor, constant: 8),
            candidateScroll.trailingAnchor.constraint(equalTo: candidateArea.trailingAnchor, constant: -4),
            candidateScroll.topAnchor.constraint(equalTo: candidateArea.topAnchor),
            candidateScrollHeight!,
            candidatePlaceholder.leadingAnchor.constraint(equalTo: codeButton.trailingAnchor, constant: 8),
            candidatePlaceholder.trailingAnchor.constraint(equalTo: candidateArea.trailingAnchor, constant: -4),
            candidatePlaceholder.centerYAnchor.constraint(equalTo: candidateArea.centerYAnchor)
        ])
        stack.addArrangedSubview(candidateArea)
        keys.axis = .vertical
        keys.spacing = 0
        keys.distribution = .fill
        stack.addArrangedSubview(keys)
        rebuildKeys()
        updateGeometry()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(table: CodeTable?, error: String? = nil) {
        engine.table = table
        engine.reset()
        loadError = error
        renderedState = nil
        displayedCode = ""
        displayedCandidates = []
        candidateLayout.setWords([])
        candidateScroll.reloadData()
        refresh()
    }

    func clearComposition() { stopRepeat(); lastShiftTap = nil; engine.reset(); refresh() }

    private func key(_ title: String, id: String? = nil, secondary: Bool = false,
                     reusing existing: UIButton? = nil, action: @escaping () -> Void) -> UIButton {
        let button = existing ?? KeyboardKeyButton(type: .system)
        button.removeAction(identifiedBy: Self.keyAction, for: .touchUpInside)
        button.accessibilityLabel = nil
        button.setImage(nil, for: .normal)
        (button as? KeyboardKeyButton)?.showsHomeMark = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        button.setTitleColor(UIColor(white: 0.12, alpha: 1), for: .normal)
        button.tintColor = UIColor(white: 0.12, alpha: 1)
        button.backgroundColor = .clear
        button.accessibilityIdentifier = id ?? "key-\(title.lowercased())"
        button.addAction(UIAction(identifier: Self.keyAction) { [weak self] _ in
            if id != "shift" { self?.lastShiftTap = nil }
            action()
        }, for: .touchUpInside)
        return button
    }

    // Every ordinary key uses the same ten-column grid, including the number row.
    @discardableResult
    private func row(_ buttons: [UIButton], kind: IaccesGeometry.Row) -> UIView {
        let wrapper = KeyRow(buttons: buttons, kind: kind)
        if bottomKeys != nil { keys.insertArrangedSubview(wrapper, at: keys.arrangedSubviews.count - 1) }
        else { keys.addArrangedSubview(wrapper) }
        return wrapper
    }

    private func insertNumber(_ raw: String) {
        if !engine.code.isEmpty, let number = Int(raw), number > 0 {
            emit(engine.choose(number - 1))
        } else { emit(engine.insertLiteral(raw)) }
    }

    private func numberRow() {
        let buttons = Array("1234567890").enumerated().map { index, character -> UIButton in
            let raw = String(character)
            let button = key(raw, id: "key-\(raw)") { [weak self] in self?.insertNumber(raw) }
            button.titleLabel?.font = .systemFont(ofSize: 25, weight: .bold)
            let symbol = Self.numberSymbols[index]
            let label = UILabel()
            label.text = symbol
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textColor = UIColor(white: 0.16, alpha: 1)
            label.isUserInteractionEnabled = false
            label.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
                label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4)
            ])
            button.tag = index
            button.accessibilityHint = "長按輸入 \(symbol)；組字時點按 1 到 9 選字"
            button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(numberSymbol(_:))))
            return button
        }
        numberKeys = row(buttons, kind: .numbers)
    }

    @objc private func numberSymbol(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let button = gesture.view as? UIButton else { return }
        let symbol = Self.numberSymbols[button.tag]
        if engine.mode == .chinese && [",", ".", "'"].contains(symbol) {
            emit(engine.type(symbol))
        } else { emit(engine.insertLiteral(symbol)) }
    }

    private func updateGeometry() {
        let compact = traitCollection.verticalSizeClass == .compact
        guard bounds.width != geometryWidth || compact != geometryCompact else { return }
        geometryWidth = bounds.width
        geometryCompact = compact
        let geometry = IaccesGeometry(width: bounds.width, compact: compact)
        let itemHeight: CGFloat = compact ? 30 : 32
        candidateHeight.constant = itemHeight
        candidateScrollHeight.constant = itemHeight
        candidateLayout.rowHeight = itemHeight
        for case let row as KeyRow in keys.arrangedSubviews {
            row.apply(geometry)
            keys.setCustomSpacing(geometry.spacing(after: row.kind), after: row)
        }
    }

    override func layoutSubviews() {
        updateGeometry()
        super.layoutSubviews()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard hit != nil, !(hit is UIControl), !isHidden, alpha > 0.01 else { return hit }
        let keyPoint = convert(point, to: keys)
        guard keyPoint.y >= 0, keyPoint.y <= keys.bounds.height else { return hit }
        var nearestRow: UIView?
        var rowDistance = CGFloat.greatestFiniteMagnitude
        for row in keys.arrangedSubviews {
            let distance = max(row.frame.minY - keyPoint.y, keyPoint.y - row.frame.maxY, 0)
            if distance < rowDistance { rowDistance = distance; nearestRow = row }
        }
        guard let row = nearestRow else { return hit }
        let rowPoint = convert(point, to: row)
        if let keyRow = row as? KeyRow { return keyRow.nearestButton(to: rowPoint) ?? hit }
        return hit
    }

    private func rebuildKeys() {
        keys.arrangedSubviews.filter { $0 !== numberKeys && $0 !== bottomKeys }.forEach {
            keys.removeArrangedSubview($0); $0.removeFromSuperview()
        }
        letterButtons.removeAll(keepingCapacity: true)
        shiftButton = nil
        if numberKeys == nil { numberRow() }
        pageButton?.setTitle(symbols ? "ABC" : "?1", for: .normal)
        let punctuation = engine.mode == .chinese ? "，。？！、：；" : "'\"!?.,:"
        let layouts = symbols
            ? (moreSymbols ? ["[]{}#%^*+=", "_\\|~<>€£¥", punctuation] : ["-/:;()$&@", "[]{}#%^*+=", punctuation])
            : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for (index, layout) in layouts.enumerated() {
            var buttons = layout.enumerated().map { position, character -> UIButton in
                let raw = String(character)
                let title = !symbols && (engine.mode == .chinese || shiftState != .off) ? raw.uppercased() : raw
                let existing = characterButtons[index].indices.contains(position) ? characterButtons[index][position] : nil
                let button = key(title, id: "key-\(raw)", reusing: existing) { [weak self] in
                    guard let self else { return }
                    if self.symbols {
                        if ["[", "]", "'"].contains(raw), self.engine.mode == .chinese {
                            self.emit(self.engine.type(raw))
                        } else if !self.engine.code.isEmpty, let number = Int(raw), number > 0 {
                            self.emit(self.engine.choose(number - 1))
                        } else { self.emit(self.engine.insertLiteral(raw)) }
                    } else {
                        let uppercase = self.shiftState != .off && self.engine.mode == .english
                        let output = self.engine.type(uppercase ? raw.uppercased() : raw)
                        if self.engine.mode == .english && self.shiftState == .once {
                            self.shiftState = .off
                            self.updateShift()
                        }
                        self.emit(output)
                    }
                }
                if existing == nil { characterButtons[index].append(button) }
                if !symbols {
                    letterButtons.append((button, raw))
                    (button as? KeyboardKeyButton)?.showsHomeMark = raw == "f" || raw == "j"
                }
                return button
            }
            if index == 2 {
                if symbols {
                    let more = key(moreSymbols ? "123" : "#+=", id: "more-symbols", secondary: true,
                                   reusing: leftSideButton) { [weak self] in
                        guard let self else { return }
                        self.moreSymbols.toggle(); self.rebuildKeys()
                    }
                    more.titleLabel?.font = .systemFont(ofSize: 15)
                    leftSideButton = more
                    buttons.insert(more, at: 0)
                } else {
                    let shift = key("⇧", id: "shift", secondary: true, reusing: leftSideButton) { [weak self] in
                        guard let self else { return }
                        self.pressShift()
                    }
                    shift.setTitle(nil, for: .normal)
                    shift.setImage(UIImage(systemName: shiftState.symbol), for: .normal)
                    shift.setPreferredSymbolConfiguration(.init(pointSize: 25, weight: .regular), forImageIn: .normal)
                    shiftButton = shift
                    updateShift()
                    leftSideButton = shift
                    buttons.insert(shift, at: 0)
                }
                if deleteButton == nil {
                    let delete = key("⌫", id: "delete", secondary: true) { [weak self] in
                        guard let self else { return }; self.emit(self.engine.backspace())
                    }
                    delete.setTitle(nil, for: .normal)
                    delete.setImage(UIImage(systemName: "delete.left.fill"), for: .normal)
                    delete.setPreferredSymbolConfiguration(.init(pointSize: 25, weight: .regular), forImageIn: .normal)
                    delete.accessibilityLabel = "刪除"
                    let hold = UILongPressGestureRecognizer(target: self, action: #selector(repeatDelete(_:)))
                    hold.minimumPressDuration = 0.4
                    delete.addGestureRecognizer(hold)
                    deleteButton = delete
                }
                buttons.append(deleteButton!)
            }
            row(buttons, kind: [.letters, .home, .lower][index])
        }
        geometryWidth = -1
        setNeedsLayout() // New row heights must update even when only the nested stack invalidates.
        guard bottomKeys == nil else { return }
        let page = key(symbols ? "ABC" : "?1", id: "symbols", secondary: true) { [weak self] in
            guard let self else { return }
            self.symbols.toggle()
            if self.symbols { self.moreSymbols = false }
            self.rebuildKeys(); self.refresh()
        }
        page.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        pageButton = page
        let space = key("", id: "space") { [weak self] in
            guard let self else { return }; self.emit(self.engine.space())
        }
        space.accessibilityLabel = "空白"
        let globe = UIButton(type: .system)
        globe.accessibilityIdentifier = "globe"
        globe.tintColor = UIColor(white: 0.16, alpha: 1)
        globe.setPreferredSymbolConfiguration(.init(pointSize: 27, weight: .light), forImageIn: .normal)
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.setTitle(nil, for: .normal)
        globe.accessibilityLabel = "切換鍵盤"
        globe.addTarget(self, action: #selector(globePressed(_:event:)), for: .allTouchEvents)
        globe.isUserInteractionEnabled = needsGlobe
        globe.isAccessibilityElement = needsGlobe
        globeButton = globe
        let mode = key("EN", id: "mode", secondary: true) { [weak self] in
            guard let self else { return }
            let previousMode = self.engine.mode
            let output = self.engine.toggleMode()
            if previousMode != self.engine.mode {
                self.shiftState = self.engine.mode == .english ? .once : .off
                self.updateShift()
            }
            self.emit(output)
            if self.symbols && previousMode != self.engine.mode { self.rebuildKeys() }
        }
        mode.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        mode.accessibilityLabel = "中文英文切換"
        modeButton = mode
        let enter = key("enter", id: "return", secondary: true) { [weak self] in
            guard let self else { return }; self.emit(self.engine.insertLiteral("\n"))
        }
        enter.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        enter.accessibilityLabel = "換行"
        let bottom = KeyRow(buttons: [page, mode, space, enter], kind: .bottom)
        bottom.globe = globe
        bottom.addSubview(globe)
        keys.addArrangedSubview(bottom)
        bottomKeys = bottom
        mode.setTitle(engine.mode == .chinese ? "EN" : "中", for: .normal)
    }

    // Keep ordinary taps immediate. A second tap within the native-style double-tap
    // window locks capitals, without delaying the first tap or installing a recognizer.
    func pressShift(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if let previous = lastShiftTap, time >= previous, time - previous <= 0.35 {
            shiftState = .locked
            lastShiftTap = nil
        } else {
            shiftState = shiftState == .off ? .once : .off
            lastShiftTap = time
        }
        updateShift()
    }

    private func updateShift() {
        for (button, raw) in letterButtons {
            button.setTitle(engine.mode == .chinese || shiftState != .off ? raw.uppercased() : raw, for: .normal)
        }
        shiftButton?.accessibilityLabel = "Shift"
        let description: String
        switch shiftState {
        case .off: description = "小寫"
        case .once: description = "下一個字母大寫"
        case .locked: description = "鎖定大寫"
        }
        shiftButton?.accessibilityValue = description
        shiftButton?.accessibilityHint = "點一下切換下一字母大寫，快速點兩下鎖定大寫"
        shiftButton?.setImage(UIImage(systemName: shiftState.symbol), for: .normal)
    }

    private func emit(_ output: CompositionEngine.Output) { onOutput?(output); refresh() }

    private func refresh() {
        let words = engine.candidates
        let state = RenderState(code: engine.code, mode: engine.mode, hint: engine.hint,
                                error: loadError, hasTable: engine.table != nil, words: words)
        guard state != renderedState else { return }
        if renderedState?.mode != state.mode { updateShift() }
        renderedState = state
        let showComposition = !engine.code.isEmpty || engine.hint != nil || loadError != nil || engine.table == nil
        if showingComposition != showComposition {
            showingComposition = showComposition
            candidateArea.alpha = showComposition ? 1 : 0
            candidateArea.accessibilityElementsHidden = !showComposition
        }
        codeButton.setTitle(engine.code.isEmpty ? "!" : engine.code.uppercased(), for: .normal)
        codeButton.accessibilityValue = engine.code
        codeButton.accessibilityHint = "長按可將字碼當作英文送出"
        modeButton?.setTitle(engine.mode == .chinese ? "EN" : "中", for: .normal)
        candidateScroll.accessibilityValue = "\(words.count) 個候選"
        codeButton.accessibilityHint = (engine.hint ?? "") + " 長按可將字碼當作英文送出"
        candidatePlaceholder.isHidden = !words.isEmpty
        candidateScroll.isHidden = words.isEmpty
        candidatePlaceholder.text = engine.hint ?? loadError ?? (engine.table == nil ? "請先匯入字碼表 · 可切換 EN" : "沒有對應字，請修改字碼")
        let codeChanged = displayedCode != engine.code
        displayedCode = engine.code
        guard !words.isEmpty else { return }
        if codeChanged { candidateScroll.setContentOffset(.zero, animated: false) }
        if displayedCandidates != words {
            displayedCandidates = words
            candidateLayout.setWords(words)
            candidateScroll.reloadData()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedCandidates.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "candidate", for: indexPath) as! CandidateCell
        let index = indexPath.item
        cell.configure(word: displayedCandidates[index], index: index)
        cell.onChoose = { [weak self] index in
            guard let self else { return }
            self.emit(self.engine.choose(index))
        }
        return cell
    }

    @objc private func sendRaw(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { emit(engine.literalComposition()) }
    }

    @objc private func globePressed(_ sender: UIButton, event: UIEvent) {
        onGlobe?(sender, event)
    }

    @objc private func repeatDelete(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            emit(engine.backspace())
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.085, repeats: true) { [weak self] _ in
                guard let self else { return }; self.emit(self.engine.backspace())
            }
        } else if [.ended, .cancelled, .failed].contains(gesture.state) { stopRepeat() }
    }

    private func stopRepeat() { repeatTimer?.invalidate(); repeatTimer = nil }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { stopRepeat() } }
}

/// One gradient and home-key mark per reusable key; layout only updates their frames.
private final class KeyboardKeyButton: UIButton {
    private let surface = CAGradientLayer()
    private let homeMark = CALayer()
    var touchInsets = UIEdgeInsets(top: 7, left: 4, bottom: 7, right: 4)
    var showsHomeMark = false { didSet { homeMark.isHidden = !showsHomeMark } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        surface.colors = [UIColor(white: 0.80, alpha: 1).cgColor, UIColor(white: 0.64, alpha: 1).cgColor]
        // A key press must change color in this event, not start a default opacity animation.
        surface.actions = ["opacity": NSNull()]
        surface.cornerRadius = 5
        surface.borderWidth = 0.5
        surface.borderColor = UIColor(white: 0.5, alpha: 1).cgColor
        layer.insertSublayer(surface, at: 0)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 1
        homeMark.backgroundColor = UIColor(white: 0.86, alpha: 1).cgColor
        homeMark.cornerRadius = 0.5
        homeMark.isHidden = true
        layer.addSublayer(homeMark)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // UIButton can insert its image view below existing layers when the image changes.
        layer.insertSublayer(surface, at: 0)
        surface.frame = bounds
        homeMark.frame = CGRect(x: bounds.midX - 7, y: bounds.height - 6, width: 14, height: 2)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 5).cgPath
        CATransaction.commit()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: -touchInsets.top, left: -touchInsets.left,
                                     bottom: -touchInsets.bottom, right: -touchInsets.right)).contains(point)
    }

    override var isHighlighted: Bool {
        didSet { surface.opacity = isHighlighted ? 0.75 : 1 }
    }
}

/// Dimensions measured from the user's 1280-pixel-wide portrait reference.
/// All phone keys scale with width; the field-height caps keep tablet/landscape keyboards usable.
private struct IaccesGeometry {
    enum Row: Int { case numbers, letters, home, lower, bottom }
    let width: CGFloat
    let compact: Bool
    private var horizontalScale: CGFloat { max(0, width) / 1280 }
    private var verticalScale: CGFloat { min(horizontalScale, (compact ? 198 : 320) / 887) }
    var fieldHeight: CGFloat { 887 * verticalScale }
    private static let heights: [CGFloat] = [138, 137, 137, 138, 137]
    private static let gaps: [CGFloat] = [48, 52, 50, 50, 0]

    func height(of row: Row) -> CGFloat { Self.heights[row.rawValue] * verticalScale }
    func spacing(after row: Row) -> CGFloat { Self.gaps[row.rawValue] * verticalScale }
    func trackingInsets(for row: Row) -> (top: CGFloat, bottom: CGFloat) {
        (row.rawValue == 0 ? 0 : Self.gaps[row.rawValue - 1] * verticalScale / 2,
         Self.gaps[row.rawValue] * verticalScale / 2)
    }

    func frames(for row: Row, count: Int) -> [CGRect] {
        let h = height(of: row)
        func rect(_ x: CGFloat, _ w: CGFloat) -> CGRect {
            CGRect(x: x * horizontalScale, y: 0, width: w * horizontalScale, height: h)
        }
        if row == .bottom { return [rect(15, 134), rect(175, 134), rect(334, 613), rect(976, 291)] }
        let sideKeys = row == .lower
        let ordinaryCount = count - (sideKeys ? 2 : 0)
        let origin = 14 + CGFloat(10 - ordinaryCount) * 127.75 / 2
        var frames = (0..<ordinaryCount).map { rect(origin + CGFloat($0) * 127.75, 104) }
        if sideKeys { frames.insert(rect(15, 142), at: 0); frames.append(rect(1124, 144)) }
        return frames
    }
}

/// Direct reference-grid frames retain reusable controls without per-key constraints.
private final class KeyRow: UIView {
    let kind: IaccesGeometry.Row
    private let buttons: [UIButton]
    private var geometry = IaccesGeometry(width: 0, compact: false)
    private var keyHeight: NSLayoutConstraint!
    var globe: UIButton?

    init(buttons: [UIButton], kind: IaccesGeometry.Row) {
        self.buttons = buttons
        self.kind = kind
        super.init(frame: .zero)
        keyHeight = heightAnchor.constraint(equalToConstant: 0)
        keyHeight.priority = .init(999)
        keyHeight.isActive = true
        for button in buttons { button.translatesAutoresizingMaskIntoConstraints = true; addSubview(button) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(_ geometry: IaccesGeometry) {
        self.geometry = geometry
        keyHeight.constant = geometry.height(of: kind)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = geometry.frames(for: kind, count: buttons.count)
        let vertical = geometry.trackingInsets(for: kind)
        for (index, button) in buttons.enumerated() {
            button.frame = frames[index]
            let left = index == 0 ? 0 : (frames[index - 1].maxX + frames[index].minX) / 2
            let right = index == buttons.count - 1 ? bounds.width : (frames[index].maxX + frames[index + 1].minX) / 2
            (button as? KeyboardKeyButton)?.touchInsets = UIEdgeInsets(top: vertical.top,
                left: button.frame.minX - left, bottom: vertical.bottom, right: right - button.frame.maxX)
        }
        if let globe, kind == .bottom {
            globe.frame = CGRect(x: buttons[2].frame.minX + 8, y: 0, width: 38, height: bounds.height)
        }
    }

    func nearestButton(to point: CGPoint) -> UIButton? {
        var nearest: UIButton?
        var distance = CGFloat.greatestFiniteMagnitude
        for button in buttons where button.isEnabled && !button.isHidden {
            let value = max(button.frame.minX - point.x, point.x - button.frame.maxX, 0)
            if value < distance { distance = value; nearest = button }
        }
        return nearest
    }
}

/// Exact frames avoid UICollectionView's estimated-size correction passes while typing.
private final class CandidateLayout: UICollectionViewLayout {
    private var starts: [CGFloat] = []
    private var widths: [CGFloat] = []
    private var contentWidth: CGFloat = 0
    var rowHeight: CGFloat = 32 {
        didSet { if rowHeight != oldValue { invalidateLayout() } }
    }

    func setWords(_ words: [String]) {
        starts.removeAll(keepingCapacity: true)
        widths.removeAll(keepingCapacity: true)
        starts.reserveCapacity(words.count)
        widths.reserveCapacity(words.count)
        var cursor: CGFloat = 0
        for word in words {
            let width = CandidateCell.width(for: word)
            starts.append(cursor)
            widths.append(width)
            cursor += width + 4
        }
        contentWidth = max(0, cursor - 4)
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

private final class CandidateCell: UICollectionViewCell {
    static let font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    private static let asciiAdvance = ("M" as NSString).size(withAttributes: [.font: font]).width
    private let button = UIButton(type: .system)
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
        button.titleLabel?.font = Self.font
        button.titleLabel?.lineBreakMode = .byClipping
        button.setTitleColor(UIColor(white: 0.12, alpha: 1), for: .normal)
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
    }

    func configure(word: String, index: Int) {
        button.tag = index
        button.setTitle(word, for: .normal)
        button.accessibilityIdentifier = "candidate-\(index)"
        button.accessibilityLabel = "候選 \(index + 1)，\(word)"
    }
}
