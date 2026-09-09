import AppKit
import CoreGraphics

final class MainWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    private let model: AppModel
    private let isDemo: Bool
    private let worker = DispatchQueue(label: "uk.magrathean.uncordex.gui-work", qos: .userInitiated)
    private var operationInFlight = false
    private var ruleChoices: [RuleChoice] = []
    private var capturedDemo = false

    private let sidebar = NSTableView()
    private let pages = NSTabView()
    private let setupActions = NSView()
    private let progress = NSProgressIndicator()
    private let serviceHint = NSTextField(wrappingLabelWithString: "")
    private let lastRefreshed = NSTextField(labelWithString: "Not refreshed yet")
    private var hasLoadedSetup = false
    private let destinations = ["Overview", "Speaker & Rule", "Diagnostics"]
    private let symbols = ["house", "hifispeaker", "waveform.path.ecg"]

    private let serviceValue = NSTextField(labelWithString: "Loading…")
    private let speakerValue = NSTextField(wrappingLabelWithString: "—")
    private let ruleValue = NSTextField(wrappingLabelWithString: "—")
    private let currentValue = NSTextField(wrappingLabelWithString: "—")
    private let cachedValue = NSTextField(wrappingLabelWithString: "—")
    private let retryValue = NSTextField(wrappingLabelWithString: "—")
    private let dependencyValue = NSTextField(wrappingLabelWithString: "Checking blueutil…")
    private let messageValue = NSTextField(wrappingLabelWithString: "")
    private let speakerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let addressField = NSTextField(string: "")
    private let rulePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var manualAddressRow: NSView?
    private let selectedBehaviorValue = NSTextField(wrappingLabelWithString: "Choose a reconnection rule")
    private let discoverButton = NSButton(title: "Find Devices & Sources", target: nil, action: nil)
    private let previewButton = NSButton(title: "Preview", target: nil, action: nil)
    private let applyButton = NSButton(title: "Save & Start", target: nil, action: nil)
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let logsButton = NSButton(title: "Open Logs", target: nil, action: nil)

    init(model: AppModel, isDemo: Bool) {
        self.model = model
        self.isDemo = isDemo
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 690),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = isDemo ? "Uncordex — Fixture Demo" : "Uncordex"
        window.minSize = NSSize(width: 760, height: 580)
        if ProcessInfo.processInfo.arguments.contains("--minimum-size") {
            window.setFrame(NSRect(origin: window.frame.origin, size: window.minSize), display: false)
        }
        window.autorecalculatesKeyViewLoop = true
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI(in: window)
        window.setContentSize(NSSize(width: 940, height: 730))
        if ProcessInfo.processInfo.arguments.contains("--minimum-size") {
            window.setFrame(NSRect(origin: window.frame.origin, size: window.minSize), display: false)
        }
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func loadInitialState() { refresh() }
    func prepareToQuit() { model.quit() }

    private func buildUI(in window: NSWindow) {
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "UncordexToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        let split = NSSplitViewController()
        let navigation = NSViewController()
        let material = NSVisualEffectView()
        material.material = .sidebar
        material.blendingMode = .behindWindow
        navigation.view = material
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("destination"))
        sidebar.addTableColumn(column)
        sidebar.headerView = nil
        sidebar.style = .sourceList
        sidebar.rowHeight = 36
        sidebar.backgroundColor = .clear
        sidebar.dataSource = self
        sidebar.delegate = self
        sidebar.setAccessibilityLabel("Navigation")
        let navigationScroll = NSScrollView()
        navigationScroll.drawsBackground = false
        navigationScroll.documentView = sidebar
        let brand = NativeLayout.label("Uncordex", size: 16, weight: .semibold)
        let caption = NativeLayout.label(isDemo ? "Demo · simulated devices" : "Your speaker, in sync.", size: 11, secondary: true)
        let sidebarRoot = NativeLayout.stack([brand, caption, navigationScroll], spacing: 6)
        NativeLayout.pin(sidebarRoot, in: material, inset: 14)
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: navigation)
        sidebarItem.minimumThickness = 215
        sidebarItem.maximumThickness = 240
        sidebarItem.canCollapse = false
        split.addSplitViewItem(sidebarItem)

        let detail = NSViewController()
        detail.view = NSView()
        pages.tabViewType = .noTabsNoBorder
        let overview = makeOverview()
        let setup = makeSetup()
        let diagnostics = makeDiagnostics()
        for (index, page) in [overview, setup, diagnostics].enumerated() {
            let item = NSTabViewItem(identifier: destinations[index])
            item.view = NativeLayout.scroll(page)
            pages.addTabViewItem(item)
        }
        messageValue.setAccessibilityLabel("Operation result")
        messageValue.isSelectable = true
        messageValue.maximumNumberOfLines = 0
        messageValue.textColor = .secondaryLabelColor
        let result = NativeLayout.scroll(NativeLayout.stack([messageValue], spacing: 0), inset: 12)
        result.heightAnchor.constraint(equalToConstant: 40).isActive = true
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        lastRefreshed.font = .systemFont(ofSize: 11)
        lastRefreshed.textColor = .secondaryLabelColor
        let footer = NSStackView(views: [progress, lastRefreshed])
        footer.spacing = 8
        let actionButtons = NSStackView(views: [previewButton, applyButton])
        actionButtons.spacing = 8
        let actionBody = NativeLayout.stack([
            NativeLayout.label("Preview makes no changes. Save & Start applies this setup and starts the service.", size: 11, secondary: true), actionButtons
        ], spacing: 8)
        NativeLayout.pin(actionBody, in: setupActions, inset: 14)
        setupActions.isHidden = true
        let body = NativeLayout.stack([pages, NativeLayout.separator(), setupActions, result, footer], spacing: 0)
        body.edgeInsets.bottom = 10
        NativeLayout.pin(body, in: detail.view)
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))
        window.contentViewController = split

        for field in [serviceValue, speakerValue, ruleValue, currentValue, cachedValue, retryValue, dependencyValue, selectedBehaviorValue, serviceHint, messageValue] {
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.maximumNumberOfLines = 0
            field.isSelectable = true
        }
        discoverButton.target = self; discoverButton.action = #selector(discover)
        previewButton.target = self; previewButton.action = #selector(preview)
        applyButton.target = self; applyButton.action = #selector(apply)
        startButton.target = self; startButton.action = #selector(start)
        stopButton.target = self; stopButton.action = #selector(stop)
        refreshButton.target = self; refreshButton.action = #selector(refreshAction)
        refreshButton.keyEquivalent = "r"; refreshButton.keyEquivalentModifierMask = [.command]
        logsButton.target = self; logsButton.action = #selector(openLogs)
        sidebar.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        rebuildPickers()
        let viewMenu = NSMenu(title: "View")
        for (index, title) in destinations.enumerated() {
            let item = viewMenu.addItem(withTitle: title, action: #selector(navigateFromMenu(_:)), keyEquivalent: String(index + 1))
            item.target = self
            item.tag = index
        }
        viewMenu.addItem(.separator())
        let refreshItem = viewMenu.addItem(withTitle: "Refresh Status", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        let menuItem = NSMenuItem()
        menuItem.title = "View"
        menuItem.submenu = viewMenu
        NSApp.mainMenu?.insertItem(menuItem, at: 2)
    }

    @objc private func navigateFromMenu(_ sender: NSMenuItem) {
        sidebar.selectRowIndexes(IndexSet(integer: sender.tag), byExtendingSelection: false)
    }

    private func makeOverview() -> NSStackView {
        serviceValue.font = .systemFont(ofSize: 23, weight: .semibold)
        serviceHint.textColor = .secondaryLabelColor
        let controls = NSStackView(views: [startButton, stopButton])
        controls.spacing = 8
        let edit = NSButton(title: "Edit Speaker & Rule…", target: self, action: #selector(showSetup))
        return NativeLayout.stack([
            NativeLayout.heading("Overview", subtitle: "Automatic speaker control, built around your power source."),
            NativeLayout.card("BACKGROUND SERVICE", symbol: "power", views: [serviceValue, serviceHint, controls]),
            NativeLayout.card("YOUR SETUP", symbol: "hifispeaker", views: [
                NativeLayout.field("Speaker", speakerValue), NativeLayout.separator(),
                NativeLayout.field("Reconnect when", ruleValue), edit]),
            NativeLayout.card("POWER & CONNECTION", symbol: "bolt", views: [
                NativeLayout.field("Latest power reading", currentValue), NativeLayout.separator(),
                NativeLayout.field("Automatic restore", retryValue)])
        ], spacing: 20)
    }

    private func makeSetup() -> NSStackView {
        speakerPopup.target = self; speakerPopup.action = #selector(speakerChanged)
        speakerPopup.setAccessibilityLabel("Paired speaker")
        addressField.placeholderString = "AA-BB-CC-DD-EE-FF"
        addressField.setAccessibilityLabel("Manual Bluetooth address")
        rulePopup.target = self; rulePopup.action = #selector(ruleChanged)
        rulePopup.setAccessibilityLabel("Reconnection rule")
        for popup in [speakerPopup, rulePopup] {
            popup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            popup.cell?.lineBreakMode = .byTruncatingTail
        }
        let manual = NativeLayout.field("Bluetooth address", addressField)
        manualAddressRow = manual
        selectedBehaviorValue.textColor = .secondaryLabelColor
        return NativeLayout.stack([
            NativeLayout.heading("Speaker & Rule", subtitle: "Choose what disconnects when you unplug, and when it reconnects."),
            NativeLayout.card("1. CHOOSE A SPEAKER", symbol: "hifispeaker", views: [
                NativeLayout.label("Use a device already paired in macOS Bluetooth settings.", secondary: true),
                discoverButton, NativeLayout.field("Paired device", speakerPopup), manual]),
            NativeLayout.card("2. SET THE RECONNECTION RULE", symbol: "arrow.triangle.branch", views: [
                NativeLayout.field("Reconnect when", rulePopup), selectedBehaviorValue]),
            NativeLayout.label("You can quit Uncordex after setup. The background service keeps running.", size: 12, secondary: true)
        ], spacing: 20)
    }

    private func makeDiagnostics() -> NSStackView {
        NativeLayout.stack([
            NativeLayout.heading("Diagnostics", subtitle: "Readings and details to help explain what the service is doing."),
            NativeLayout.card("LAST SERVICE OBSERVATION", symbol: "clock", views: [cachedValue,
                NativeLayout.label("This is a cached observation, not a live Bluetooth connection check. Refresh reads the latest saved observation.", size: 12, secondary: true)]),
            NativeLayout.card("BLUETOOTH HELPER", symbol: "puzzlepiece.extension", views: [dependencyValue]),
            NativeLayout.card("LOGS", symbol: "doc.text.magnifyingglass", views: [
                NativeLayout.label("Open the log folder to inspect service activity and errors.", secondary: true), logsButton])
        ], spacing: 20)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { destinations.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let image = NSImageView(image: NSImage(systemSymbolName: symbols[row], accessibilityDescription: nil)!)
        image.contentTintColor = .controlAccentColor
        image.widthAnchor.constraint(equalToConstant: 20).isActive = true
        let label = NSTextField(labelWithString: destinations[row])
        label.font = .systemFont(ofSize: 13)
        let cell = NSTableCellView()
        let line = NSStackView(views: [image, label])
        line.spacing = 9
        NativeLayout.pin(line, in: cell, inset: 4)
        cell.textField = label
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard sidebar.selectedRow >= 0 else { return }
        pages.selectTabViewItem(at: sidebar.selectedRow)
        window?.subtitle = destinations[sidebar.selectedRow]
        // Return is a setup action only while its page is visible.
        setupActions.isHidden = sidebar.selectedRow != 1
        applyButton.keyEquivalent = sidebar.selectedRow == 1 ? "\r" : ""
        window?.makeFirstResponder(sidebar)
    }

    @objc private func showSetup() { sidebar.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false) }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, NSToolbarItem.Identifier("refresh")] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard identifier.rawValue == "refresh" else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = "Refresh"
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.imagePosition = .imageOnly
        refreshButton.bezelStyle = .texturedRounded
        refreshButton.toolTip = "Refresh status (⌘R)"
        item.view = refreshButton
        return item
    }

    private func rebuildPickers() {
        let draftAddress = hasLoadedSetup ? chosenAddress() : nil
        let draftRule = hasLoadedSetup ? chosenRule() : nil
        let wasManual = hasLoadedSetup && speakerPopup.indexOfSelectedItem == speakerPopup.numberOfItems - 1
        let configured = model.snapshot.deviceAddress
        speakerPopup.removeAllItems()
        for speaker in model.speakers {
            let suffix = speaker.connected ? " • connected" : ""
            speakerPopup.addItem(withTitle: "\(speaker.name) — \(speaker.address)\(suffix)")
        }
        if !configured.isEmpty && !model.speakers.contains(where: { $0.address.caseInsensitiveCompare(configured) == .orderedSame }) {
            speakerPopup.addItem(withTitle: "Configured speaker — \(configured)")
        }
        speakerPopup.addItem(withTitle: "Enter address manually…")
        if let configuredIndex = model.speakers.firstIndex(where: { $0.address.caseInsensitiveCompare(configured) == .orderedSame }) {
            speakerPopup.selectItem(at: configuredIndex)
        } else if !configured.isEmpty {
            speakerPopup.selectItem(at: model.speakers.count)
        }
        if !configured.isEmpty { addressField.stringValue = configured }

        ruleChoices = []
        if model.snapshot.configState == "valid", model.snapshot.reconnectMode == "source", !model.snapshot.sourceKey.isEmpty {
            ruleChoices.append(.savedSource(SourceCandidate(kind: model.snapshot.sourceKind, label: model.snapshot.sourceLabel, key: model.snapshot.sourceKey)))
        }
        for source in model.sources where !ruleChoices.contains(where: { choice in
            if case .savedSource(let existing) = choice { return existing.key == source.key }
            return false
        }) { ruleChoices.append(.savedSource(source)) }
        ruleChoices.append(.anyPower)
        ruleChoices.append(.disconnectOnly)
        rulePopup.removeAllItems()
        rulePopup.addItem(withTitle: "Choose a reconnection rule…")
        ruleChoices.forEach { rulePopup.addItem(withTitle: $0.title) }
        if model.snapshot.configState == "valid" && model.snapshot.reconnectMode == "source" && !model.snapshot.sourceKey.isEmpty { rulePopup.selectItem(at: 1) }
        if model.snapshot.configState == "valid" && model.snapshot.reconnectMode == "any_power" { rulePopup.selectItem(at: max(1, ruleChoices.count - 1)) }
        if model.snapshot.configState == "valid" && model.snapshot.reconnectMode == "disconnect_only" { rulePopup.selectItem(at: max(1, ruleChoices.count)) }
        if let address = draftAddress {
            addressField.stringValue = address
            if wasManual { speakerPopup.selectItem(at: speakerPopup.numberOfItems - 1) }
            else if let index = model.speakers.firstIndex(where: { $0.address.caseInsensitiveCompare(address) == .orderedSame }) {
                speakerPopup.selectItem(at: index)
            } else if address.caseInsensitiveCompare(configured) != .orderedSame {
                speakerPopup.selectItem(at: speakerPopup.numberOfItems - 1)
            }
            if let rule = draftRule {
                if !ruleChoices.contains(rule) {
                    ruleChoices.append(rule)
                    rulePopup.addItem(withTitle: rule.title)
                }
                if let index = ruleChoices.firstIndex(of: rule) { rulePopup.selectItem(at: index + 1) }
            } else { rulePopup.selectItem(at: 0) }
        }
        speakerChanged()
        ruleChanged()
    }

    private func render() {
        let state = model.snapshot
        serviceValue.stringValue = state.service.title
        serviceValue.textColor = state.service == .running ? .systemGreen : .labelColor
        switch state.service {
        case .running: serviceHint.stringValue = "Watching your power source. It keeps running when you quit this app."
        case .stopped: serviceHint.stringValue = "Automatic speaker control is stopped. Your saved setup is retained."
        case .notInstalled: serviceHint.stringValue = "Choose a speaker and rule to get started."
        case .loadedNotRunning: serviceHint.stringValue = "The service needs attention. Restart it or inspect Diagnostics."
        }
        lastRefreshed.stringValue = "Updated " + DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        speakerValue.stringValue = state.deviceAddress.isEmpty ? "Not configured" : state.deviceAddress
        switch state.reconnectMode {
        case "source": ruleValue.stringValue = state.sourceLabel.isEmpty ? "Saved exact source" : state.sourceLabel
        case "any_power": ruleValue.stringValue = "Any external power"
        case "disconnect_only": ruleValue.stringValue = "Disconnect only"
        default: ruleValue.stringValue = "Not configured"
        }
        let sourceNow = state.currentSource == "not_applicable" ? "source not applicable" : "source \(friendly(state.currentSource))"
        currentValue.stringValue = "\(friendly(state.currentPower)); \(sourceNow) — read now"
        if let watcher = state.watcher, watcher.isValid {
            let date = watcher.observedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? "unknown time"
            cachedValue.stringValue = "\(friendly(watcher.lastPower)); source \(friendly(watcher.lastSource)) — cached at \(date)"
            retryValue.stringValue = retryDescription(watcher, service: state.service)
        } else {
            cachedValue.stringValue = "No valid cached watcher observation"
            retryValue.stringValue = "No watcher-owned reconnect is pending"
        }
        dependencyValue.stringValue = state.blueutilAvailable ? "blueutil available at \(state.blueutilPath)" : "Missing blueutil. Run: brew install blueutil"
        dependencyValue.textColor = state.blueutilAvailable ? .secondaryLabelColor : .systemRed
        var problems = [String]()
        if !state.configError.isEmpty { problems.append(state.configError) }
        if !state.blueutilAvailable { problems.append("Bluetooth helper missing. Install it with: brew install blueutil") }
        if !state.watcherError.isEmpty { problems.append(state.watcherError) }
        if case .loadedNotRunning(let detail) = state.service {
            problems.append("The LaunchAgent is loaded but not running (\(detail)). Restart it, or stop it before correcting setup.")
        }
        messageValue.stringValue = problems.joined(separator: " ")
        let needsAttention = !state.blueutilAvailable || state.configState == "invalid" || !state.watcherError.isEmpty || state.service.canStart && state.service.canStop
        messageValue.textColor = needsAttention ? .systemRed : .secondaryLabelColor
        updateControls()
        rebuildPickers()
        if !hasLoadedSetup {
            hasLoadedSetup = true
            if state.configState == "missing" { showSetup() }
        }
        if isDemo, let flag = ProcessInfo.processInfo.arguments.firstIndex(of: "--page"),
           ProcessInfo.processInfo.arguments.indices.contains(flag + 1),
           let index = Int(ProcessInfo.processInfo.arguments[flag + 1]), destinations.indices.contains(index) {
            sidebar.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        captureDemoIfRequested()
    }

    private func friendly(_ value: String) -> String {
        switch value {
        case "ac": return "External power"
        case "battery": return "Battery"
        case "match": return "matched"
        case "absent": return "absent"
        case "unknown": return "unknown"
        default: return value.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func retryDescription(_ watcher: WatcherStatus, service: ServiceAvailability) -> String {
        if service != .running {
            switch service {
            case .stopped: return "Cached retry state: \(friendly(watcher.phase)); service is stopped"
            case .notInstalled: return "Cached retry state: \(friendly(watcher.phase)); service is not installed"
            case .loadedNotRunning: return "Cached retry state: \(friendly(watcher.phase)); loaded service is not running"
            case .running: break
            }
        }
        switch watcher.phase {
        case "pending": return "Pending automatic restore; attempt \(watcher.attempts) of 6"
        case "paused": return "Automatic retries paused until a genuine depart-and-return cycle"
        case "disconnecting": return "Waiting to confirm disconnect"
        default: return "Idle; no watcher-owned reconnect is pending"
        }
    }

    private func captureDemoIfRequested() {
        guard isDemo, !capturedDemo,
              let flag = ProcessInfo.processInfo.arguments.firstIndex(of: "--screenshot"),
              ProcessInfo.processInfo.arguments.indices.contains(flag + 1), window != nil else { return }
        capturedDemo = true
        let destination = ProcessInfo.processInfo.arguments[flag + 1]
        window?.orderFrontRegardless()
        window?.displayIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let window = self?.window,
                  let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) else { return }
            let bitmap = NSBitmapImageRep(cgImage: image)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: destination), options: .atomic)
            }
            NSApp.terminate(nil)
        }
    }

    private func chosenAddress() -> String {
        let index = speakerPopup.indexOfSelectedItem
        if index >= 0 && index < model.speakers.count { return model.speakers[index].address }
        return addressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func chosenRule() -> RuleChoice? {
        explicitRuleChoice(popupIndex: rulePopup.indexOfSelectedItem, choices: ruleChoices)
    }

    private func perform(mutation: Bool = false, work: @escaping () throws -> String, completion: (() -> Void)? = nil) {
        guard !operationInFlight else { return }
        operationInFlight = true
        progress.startAnimation(nil)
        setControlsEnabled(false)
        messageValue.stringValue = mutation ? "Working…" : "Refreshing…"
        messageValue.textColor = .secondaryLabelColor
        worker.async { [weak self] in
            guard let self else { return }
            let result: Result<String, Error>
            do { result = .success(try work()) } catch { result = .failure(error) }
            DispatchQueue.main.async {
                self.operationInFlight = false
                self.progress.stopAnimation(nil)
                var succeeded = false
                switch result {
                case .success(let message):
                    succeeded = true
                    self.messageValue.stringValue = message
                    self.messageValue.textColor = .secondaryLabelColor
                case .failure(let error):
                    self.messageValue.stringValue = error.localizedDescription
                    self.messageValue.textColor = .systemRed
                }
                self.updateControls()
                if succeeded { completion?() }
            }
        }
    }

    private func setControlsEnabled(_ enabled: Bool) {
        [discoverButton, previewButton, applyButton, startButton, stopButton, refreshButton].forEach { $0.isEnabled = enabled }
        speakerPopup.isEnabled = enabled
        rulePopup.isEnabled = enabled
        if !enabled { addressField.isEnabled = false }
    }

    private func updateControls() {
        guard !operationInFlight else { setControlsEnabled(false); return }
        let state = model.snapshot
        speakerPopup.isEnabled = true
        rulePopup.isEnabled = true
        speakerChanged()
        if case .loadedNotRunning = state.service { startButton.title = "Restart" }
        else { startButton.title = "Start" }
        startButton.isEnabled = state.service.canStart
        stopButton.isEnabled = state.service.canStop
        applyButton.isEnabled = state.blueutilAvailable && chosenRule() != nil
        previewButton.isEnabled = state.blueutilAvailable && chosenRule() != nil
        discoverButton.isEnabled = state.blueutilAvailable
        refreshButton.isEnabled = true
    }

    private func refresh() {
        perform(work: { [model] in try model.refresh(); return "" }, completion: { [weak self] in self?.render() })
    }

    @objc private func refreshAction() { refresh() }

    @objc private func discover() {
        perform(work: { [model] in
            try model.discover()
            return "Found \(model.speakers.count) paired device(s) and \(model.sources.count) exact source(s)."
        }, completion: { [weak self] in self?.rebuildPickers() })
    }

    @objc private func speakerChanged() {
        let manual = speakerPopup.indexOfSelectedItem == speakerPopup.numberOfItems - 1
        manualAddressRow?.isHidden = !manual
        addressField.isEnabled = manual && !operationInFlight
    }

    @objc private func ruleChanged() {
        switch chosenRule() {
        case .savedSource(let source): selectedBehaviorValue.stringValue = "Reconnect only when this exact source returns: \(source.label). Other chargers and docks won’t trigger a restore."
        case .anyPower: selectedBehaviorValue.stringValue = "Reconnect when any external power returns, including a different charger or dock."
        case .disconnectOnly: selectedBehaviorValue.stringValue = "Disconnect when external power leaves. Reconnect the speaker yourself when you need it."
        case nil: selectedBehaviorValue.stringValue = "Choose a rule explicitly. Nothing will be saved until you select Save & Start."
        }
        updateControls()
    }

    @objc private func preview() {
        guard let rule = chosenRule() else { messageValue.stringValue = "Choose a reconnection rule."; return }
        let address = chosenAddress()
        perform(work: { [model] in try model.preview(address: address, rule: rule) })
    }

    @objc private func apply() {
        guard let rule = chosenRule() else { messageValue.stringValue = "Choose a reconnection rule."; return }
        let address = chosenAddress()
        perform(mutation: true, work: { [model] in try model.apply(address: address, rule: rule) }, completion: { [weak self] in self?.hasLoadedSetup = false; self?.refresh() })
    }

    @objc private func start() {
        perform(mutation: true, work: { [model] in try model.start(); return "Service started." }, completion: { [weak self] in self?.refresh() })
    }

    @objc private func stop() {
        perform(mutation: true, work: { [model] in try model.stop(); return "Service stopped. Configuration and state were retained." }, completion: { [weak self] in self?.refresh() })
    }

    @objc private func openLogs() {
        let directory = model.logsDirectory
        guard FileManager.default.fileExists(atPath: directory.path) else {
            messageValue.stringValue = "No log directory exists yet: \(directory.path)"
            messageValue.textColor = .systemRed
            return
        }
        NSWorkspace.shared.open(directory)
    }
}
