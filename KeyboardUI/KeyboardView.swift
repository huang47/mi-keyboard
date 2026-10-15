import UIKit

final class KeyboardView: UIView, UICollectionViewDataSource {
    var engine = CompositionEngine()
    var onOutput: ((CompositionEngine.Output) -> Void)?
    var onGlobe: ((UIView, UIEvent) -> Void)? {
        didSet { updateGlobeAccessibility(); geometryWidth = -1; setNeedsLayout() }
    }
    private let codeButton = UIButton(type: .system)
    private let codeLabel = UILabel()
    private let candidateArea = UIView()
    private let candidatePlaceholder = UILabel()
    private let candidateLayout = CandidateListLayout()
    private lazy var candidateScroll = UICollectionView(frame: .zero, collectionViewLayout: candidateLayout)
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
    private let keys = UIView()
    private var rows: [KeyboardRow] = []
    private var keyPreview: KeyPreview?
    private weak var previewedKey: KeyboardButton?
    private var geometryWidth: CGFloat = -1
    private var geometryCompact: Bool?
    private var geometryViewportWidth: CGFloat = -1
    private var geometryOriginX: CGFloat = -1
    private static let numberSymbols = [".", ",", ":", "/", "@", "-", "!", "?", "'", "$"]

    static func preferredHeight(width: CGFloat, compact: Bool) -> CGFloat {
        12 + (compact ? 30 : 32) + NativeKeyboardGeometry(width: width, compact: compact).fieldHeight
    }
    private var showingComposition = true
    var isShowingComposition: Bool { showingComposition }
    private enum Page { case letters, symbols, moreSymbols }
    private var page = Page.letters
    private var showingSymbols: Bool { page != .letters }
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
    private var displayedShiftState: ShiftState?
    private var lastShiftTap: TimeInterval?
    private var repeatTimer: Timer?
    private weak var globeButton: UIButton?
    private weak var pageButton: UIButton?
    private weak var shiftButton: UIButton?
    private var letterButtons: [(UIButton, String)] = []
    private var numberKeys: KeyboardRow?
    private var bottomKeys: KeyboardRow?
    private var characterButtons: [[KeyboardButton]] = [[], [], []]
    private var leftSideButton: UIButton?
    private var deleteButton: UIButton?
    private static let keyAction = UIAction.Identifier("keyboard-key")
    // Hosts can disable the globe; the extension and in-app practice keep it enabled.
    var needsGlobe = true {
        didSet {
            globeButton?.isUserInteractionEnabled = needsGlobe
            globeButton?.isAccessibilityElement = needsGlobe
        }
    }
    var loadError: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(red: 0.886, green: 0.89, blue: 0.906, alpha: 1) }
        addSubview(candidateArea)
        addSubview(keys)
        // Plain labels have no UIButton title transition and need no forced layout.
        codeLabel.font = .monospacedSystemFont(ofSize: 17, weight: .semibold)
        codeLabel.textColor = .label
        codeLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        codeLabel.frame = codeButton.bounds
        codeLabel.isUserInteractionEnabled = false
        codeLabel.isAccessibilityElement = false
        codeLabel.accessibilityIdentifier = "composition-text"
        codeButton.addSubview(codeLabel)
        codeButton.contentHorizontalAlignment = .left
        codeButton.accessibilityIdentifier = "composition"
        codeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        codeButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(sendRaw(_:))))
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateArea.clipsToBounds = true
        candidateScroll.backgroundColor = .clear
        candidateScroll.dataSource = self
        candidateScroll.register(CandidateListCell.self, forCellWithReuseIdentifier: "candidate")
        candidateScroll.accessibilityIdentifier = "candidate-list"
        candidateArea.addSubview(codeButton)
        candidateArea.addSubview(candidateScroll)
        candidatePlaceholder.font = .systemFont(ofSize: 14)
        candidatePlaceholder.textColor = .secondaryLabel
        candidateArea.addSubview(candidatePlaceholder)
        rebuildKeys()
        updateGeometry()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(table: CodeTable?, error: String? = nil) {
        hideKeyPreview()
        engine.table = table
        engine.reset()
        loadError = error
        renderedState = nil
        displayedCandidates = []
        candidateLayout.clearCache()
        candidateLayout.setWords([])
        candidateScroll.reloadData()
        refresh()
    }

    func clearComposition() { hideKeyPreview(); stopRepeat(); lastShiftTap = nil; engine.reset(); refresh() }

    private func configurePreview(_ button: KeyboardButton) {
        button.onHighlightChange = { [weak self] button in
            guard let self else { return }
            if button.isHighlighted {
                let preview = self.keyPreview ?? KeyPreview()
                if self.keyPreview == nil { self.keyPreview = preview; self.addSubview(preview) }
                self.previewedKey = button
                preview.show(title: button.title(for: .normal) ?? "", keyFrame: button.convert(button.bounds, to: self), width: self.bounds.width)
                self.bringSubviewToFront(preview)
            } else if self.previewedKey === button { self.hideKeyPreview() }
        }
    }

    private func hideKeyPreview() {
        previewedKey = nil
        UIView.performWithoutAnimation { keyPreview?.isHidden = true }
    }

    private func key(_ title: String, id: String? = nil, reusing existing: UIButton? = nil, action: @escaping () -> Void) -> UIButton {
        let button = existing ?? KeyboardButton(type: .custom)
        if existing == nil, id?.hasPrefix("key-") == true, let characterKey = button as? KeyboardButton {
            configurePreview(characterKey)
        }
        button.removeAction(identifiedBy: Self.keyAction, for: .touchUpInside)
        button.accessibilityLabel = nil
        button.setImage(nil, for: .normal)
        button.setTitle(title, for: .normal)
        if existing == nil { (button as? KeyboardButton)?.configureAppearance() }
        button.accessibilityIdentifier = id ?? "key-\(title.lowercased())"
        button.addAction(UIAction(identifier: Self.keyAction) { [weak self] _ in
            if id != "shift" { self?.lastShiftTap = nil }
            action()
        }, for: .touchUpInside)
        return button
    }

    // Rows persist across alphabet and symbol pages; only their controls change.
    @discardableResult
    private func row(_ buttons: [UIButton], kind: NativeKeyboardGeometry.Row) -> KeyboardRow {
        if let existing = rows.first(where: { $0.kind == kind }) {
            existing.setButtons(buttons)
            return existing
        }
        let row = KeyboardRow(buttons: buttons, kind: kind)
        rows.append(row)
        keys.addSubview(row)
        return row
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
            button.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
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
            button.accessibilityHint = index == 8
                ? "中文長按開始同音查詢；組字時點按選第九個候選"
                : "長按輸入 \(symbol)；組字時點按 1 到 9 選字"
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
        // iOS reserves side rails for its globe/dictation controls in landscape.
        // Use screen coordinates once, then translate the native caps into our owned view.
        let screenBounds = window?.screen.bounds ?? bounds
        let viewportWidth = onGlobe != nil && compact ? max(screenBounds.width, screenBounds.height) : bounds.width
        // The extension's remote window uses a local origin; its owned landscape
        // canvas is centered between the system's two rails in the host screen.
        let originX = onGlobe != nil && compact ? max(0, (viewportWidth - bounds.width) / 2) : 0
        guard bounds.width != geometryWidth || compact != geometryCompact || viewportWidth != geometryViewportWidth || originX != geometryOriginX else { return }
        geometryWidth = bounds.width
        geometryCompact = compact
        geometryViewportWidth = viewportWidth
        geometryOriginX = originX
        hideKeyPreview()
        let geometry = NativeKeyboardGeometry(width: viewportWidth, compact: compact, scale: traitCollection.displayScale)
        let itemHeight: CGFloat = compact ? 30 : 32
        candidateArea.frame = CGRect(x: 0, y: 6, width: bounds.width, height: itemHeight)
        codeButton.frame = CGRect(x: 4, y: 0, width: 60, height: itemHeight)
        let candidateFrame = CGRect(x: 72, y: 0, width: max(0, bounds.width - 76), height: itemHeight)
        candidateScroll.frame = candidateFrame
        candidatePlaceholder.frame = candidateFrame
        candidateLayout.rowHeight = itemHeight
        keys.frame = CGRect(x: 0, y: itemHeight + 12, width: bounds.width, height: geometry.fieldHeight)
        for row in rows {
            row.frame = CGRect(x: 0, y: geometry.origin(of: row.kind), width: bounds.width, height: geometry.height(of: row.kind))
            row.apply(geometry, horizontalOffset: -originX)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGeometry()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard hit != nil, !(hit is UIControl), !isHidden, alpha > 0.01 else { return hit }
        let keyPoint = convert(point, to: keys)
        guard keyPoint.y >= 0, keyPoint.y <= keys.bounds.height else { return hit }
        var nearestRow: KeyboardRow?
        var rowDistance = CGFloat.greatestFiniteMagnitude
        for row in rows {
            let distance = max(row.frame.minY - keyPoint.y, keyPoint.y - row.frame.maxY, 0)
            if distance < rowDistance { rowDistance = distance; nearestRow = row }
        }
        guard let row = nearestRow else { return hit }
        let rowPoint = convert(point, to: row)
        return row.nearestButton(to: rowPoint) ?? hit
    }

    private func rebuildKeys() {
        hideKeyPreview()
        letterButtons.removeAll(keepingCapacity: true)
        shiftButton = nil
        displayedShiftState = nil
        if numberKeys == nil { numberRow() }
        pageButton?.setTitle(showingSymbols ? "ABC" : "123", for: .normal)
        let punctuation = engine.mode == .chinese ? "，。？！、：；" : "'\"!?.,:"
        let layouts = showingSymbols
            ? (page == .moreSymbols ? ["[]{}#%^*+=", "_\\|~<>€£¥", punctuation] : ["-/:;()$&@", "[]{}#%^*+=", punctuation])
            : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for (index, layout) in layouts.enumerated() {
            var buttons = layout.enumerated().map { position, character -> UIButton in
                let raw = String(character)
                let title = !showingSymbols && (engine.mode == .chinese || shiftState != .off) ? raw.uppercased() : raw
                let existing = characterButtons[index].indices.contains(position) ? characterButtons[index][position] : nil
                let button = existing ?? KeyboardButton(type: .custom)
                if existing == nil {
                    configurePreview(button)
                    button.addAction(UIAction { [weak self, weak button] _ in
                        guard let button else { return }
                        self?.typeCharacter(button)
                    }, for: .touchUpInside)
                    characterButtons[index].append(button)
                }
                button.input = raw
                button.setTitle(title, for: .normal)
                if existing == nil { button.configureAppearance() }
                button.accessibilityIdentifier = "key-\(raw)"
                if !showingSymbols {
                    letterButtons.append((button, raw))
                }
                return button
            }
            if index == 2 {
                if showingSymbols {
                    let more = key(page == .moreSymbols ? "123" : "#+=", id: "more-symbols",
                                   reusing: leftSideButton) { [weak self] in
                        guard let self else { return }
                        self.page = self.page == .moreSymbols ? .symbols : .moreSymbols
                        self.rebuildKeys()
                    }
                    more.titleLabel?.font = .systemFont(ofSize: 15)
                    leftSideButton = more
                    buttons.insert(more, at: 0)
                } else {
                    let shift = key("⇧", id: "shift", reusing: leftSideButton) { [weak self] in
                        guard let self else { return }
                        self.pressShift()
                    }
                    shift.setTitle(nil, for: .normal)
                    shift.setImage(UIImage(systemName: shiftState.symbol), for: .normal)
                    shift.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular), forImageIn: .normal)
                    shiftButton = shift
                    updateShift()
                    leftSideButton = shift
                    buttons.insert(shift, at: 0)
                }
                if deleteButton == nil {
                    let delete = key("⌫", id: "delete") { [weak self] in
                        guard let self else { return }; self.emit(self.engine.backspace())
                    }
                    delete.setTitle(nil, for: .normal)
                    delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
                    delete.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular), forImageIn: .normal)
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
        setNeedsLayout()
        guard bottomKeys == nil else { return }
        let page = key(showingSymbols ? "ABC" : "123", id: "symbols") { [weak self] in
            guard let self else { return }
            self.page = self.showingSymbols ? .letters : .symbols
            self.rebuildKeys(); self.refresh()
        }
        page.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        pageButton = page
        let space = key("", id: "space") { [weak self] in
            guard let self else { return }; self.emit(self.engine.space())
        }
        space.accessibilityLabel = "空白"
        let globe = UIButton(type: .system)
        globe.accessibilityIdentifier = "globe"
        globe.tintColor = .label
        globe.setPreferredSymbolConfiguration(.init(pointSize: 27, weight: .light), forImageIn: .normal)
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.setTitle(nil, for: .normal)
        globe.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.33, alpha: 1) : .white }
        globe.layer.cornerRadius = 8
        globe.accessibilityLabel = "切換鍵盤"
        globe.addTarget(self, action: #selector(globePressed(_:event:)), for: .allTouchEvents)
        globe.isUserInteractionEnabled = needsGlobe
        globe.isAccessibilityElement = needsGlobe
        globeButton = globe
        // The preview switches internal language; the extension delegates to iOS.
        globe.addAction(UIAction { [weak self] _ in
            guard let self, self.onGlobe == nil else { return }
            self.lastShiftTap = nil
            let previousMode = self.engine.mode
            let output = self.engine.toggleMode()
            if previousMode != self.engine.mode {
                self.shiftState = self.engine.mode == .english ? .once : .off
            }
            self.emit(output)
            if self.showingSymbols && previousMode != self.engine.mode { self.rebuildKeys() }
        }, for: .touchUpInside)
        let enter = key("", id: "return") { [weak self] in
            guard let self else { return }; self.emit(self.engine.insertLiteral("\n"))
        }
        enter.setImage(UIImage(systemName: "return"), for: .normal)
        enter.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular), forImageIn: .normal)
        enter.accessibilityLabel = "換行"
        let bottom = row([page, globe, space, enter], kind: .bottom)
        bottomKeys = bottom
        updateGlobeAccessibility()
    }

    private func updateGlobeAccessibility() {
        globeButton?.accessibilityLabel = onGlobe == nil ? "中文英文切換" : "切換鍵盤"
        globeButton?.accessibilityValue = onGlobe == nil ? (engine.mode == .chinese ? "中文" : "英文") : nil
        globeButton?.accessibilityHint = onGlobe == nil ? "點按切換練習的中英文模式" : "點按切換系統鍵盤，長按選擇 English 或其他鍵盤"
    }

    private func typeCharacter(_ button: KeyboardButton) {
        lastShiftTap = nil
        let raw = button.input
        if showingSymbols {
            if ["[", "]", "'"].contains(raw), engine.mode == .chinese { emit(engine.type(raw)) }
            else { emit(engine.insertLiteral(raw)) }
        } else {
            let uppercase = shiftState != .off && engine.mode == .english
            let output = engine.type(uppercase ? raw.uppercased() : raw)
            if engine.mode == .english && shiftState == .once {
                shiftState = .off
                updateShift()
            }
            emit(output)
        }
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
            let title = engine.mode == .chinese || shiftState != .off ? raw.uppercased() : raw
            if button.title(for: .normal) != title { button.setTitle(title, for: .normal) }
        }
        guard displayedShiftState != shiftState else { return }
        displayedShiftState = shiftState
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
        let previous = renderedState
        if previous?.mode != state.mode {
            updateShift()
            updateGlobeAccessibility()
        }
        renderedState = state
        let showComposition = !engine.code.isEmpty || engine.hint != nil || loadError != nil || engine.table == nil
        let visibilityChanged = showingComposition != showComposition
        if visibilityChanged {
            showingComposition = showComposition
            candidateArea.alpha = showComposition ? 1 : 0
            candidateArea.accessibilityElementsHidden = !showComposition
        }
        let codeChanged = previous?.code != state.code
        if codeChanged || (showComposition && visibilityChanged) {
            // A hidden label does not need a new title after committing or clearing.
            // Refresh on becoming visible so error/hint states cannot show stale code.
            if showComposition {
                let codeText = state.code.isEmpty ? "!" : state.code.uppercased()
                if codeLabel.text != codeText { codeLabel.text = codeText }
                codeButton.accessibilityLabel = codeText
            }
            codeButton.accessibilityValue = state.code
        }
        if previous?.words.count != words.count {
            candidateScroll.accessibilityValue = "\(words.count) 個候選"
            candidatePlaceholder.isHidden = !words.isEmpty
            candidateScroll.isHidden = words.isEmpty
        }
        if previous == nil || previous?.hint != state.hint || previous?.error != state.error || previous?.hasTable != state.hasTable {
            codeButton.accessibilityHint = (state.hint ?? "") + " 長按可將字碼當作英文送出"
            candidatePlaceholder.text = state.hint ?? state.error ?? (state.hasTable ? "沒有對應字，請修改字碼" : "內建字碼表無法載入 · 請更新 App")
        }
        guard !words.isEmpty else { return }
        if codeChanged { candidateScroll.setContentOffset(.zero, animated: false) }
        if displayedCandidates != words {
            let sameCount = displayedCandidates.count == words.count
            displayedCandidates = words
            candidateLayout.setWords(words, forCode: engine.code)
            if sameCount {
                // The item identities are positional. Keep existing visible controls and
                // let the layout fetch any newly visible cells after widths change.
                candidateScroll.layoutIfNeeded()
                for case let cell as CandidateListCell in candidateScroll.visibleCells {
                    guard let index = candidateScroll.indexPath(for: cell)?.item else { continue }
                    cell.configure(word: words[index], index: index)
                }
            } else { candidateScroll.reloadData() }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedCandidates.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "candidate", for: indexPath) as! CandidateListCell
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
    override func didMoveToWindow() {
        super.didMoveToWindow()
        geometryWidth = -1
        setNeedsLayout()
        if window == nil { hideKeyPreview(); stopRepeat() }
    }
}
