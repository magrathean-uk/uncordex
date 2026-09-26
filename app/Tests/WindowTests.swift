import AppKit

private var passed = 0
private var failed = 0

private func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() { passed += 1; print("ok - \(name)") }
    else { failed += 1; print("not ok - \(name)") }
}

private func waitForMainQueue() {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}

private let testSnapshot = AppSnapshot(
    service: .notInstalled, configState: "missing", configError: "",
    deviceAddress: "", reconnectMode: "", sourceKind: "", sourceKey: "", sourceLabel: "",
    currentPower: "unknown", currentSource: "unknown", blueutilAvailable: true, blueutilPath: "/fixture/blueutil",
    watcher: nil, watcherError: ""
)

private class WindowFixtureAdapter: ServiceAdapting {
    var logsDirectory = URL(fileURLWithPath: "/tmp")
    let refreshFinished = DispatchSemaphore(value: 0)
    func refresh() throws -> AppSnapshot {
        defer { refreshFinished.signal() }
        return testSnapshot
    }
    func pairedSpeakers() throws -> [PairedSpeaker] { [] }
    func discoverSources() throws -> [SourceCandidate] { [] }
    func preview(address: String, rule: RuleChoice) throws -> String { "preview" }
    func apply(address: String, rule: RuleChoice) throws -> String { "apply" }
    func start() throws {}
    func stop() throws {}
}

private final class BlockingRefreshAdapter: WindowFixtureAdapter {
    let refreshStarted = DispatchSemaphore(value: 0)
    let allowRefresh = DispatchSemaphore(value: 0)

    override func refresh() throws -> AppSnapshot {
        refreshStarted.signal()
        _ = allowRefresh.wait(timeout: .now() + 2)
        refreshFinished.signal()
        return testSnapshot
    }
}

private final class ReorderingDiscoveryAdapter: WindowFixtureAdapter {
    private let first = [
        PairedSpeaker(name: "Alpha", address: "AA-BB-CC-DD-EE-FF", connected: false),
        PairedSpeaker(name: "Beta", address: "11-22-33-44-55-66", connected: false)
    ]
    private var round = 0
    let discoveryFinished = DispatchSemaphore(value: 0)

    override func pairedSpeakers() throws -> [PairedSpeaker] {
        round == 0 ? first : Array(first.reversed())
    }

    override func discoverSources() throws -> [SourceCandidate] {
        defer {
            round += 1
            discoveryFinished.signal()
        }
        return []
    }
}

private func pairedSpeakerPopup(in view: NSView) -> NSPopUpButton? {
    if let popup = view as? NSPopUpButton, popup.accessibilityLabel() == "Paired speaker" { return popup }
    for subview in view.subviews {
        if let popup = pairedSpeakerPopup(in: subview) { return popup }
    }
    return nil
}

@main
private enum WindowTests {
    static func main() {
        _ = NSApplication.shared

        let blocking = BlockingRefreshAdapter()
        let blockingController = MainWindowController(model: AppModel(adapter: blocking), isDemo: true)
        blockingController.loadInitialState()
        check(blocking.refreshStarted.wait(timeout: .now() + 1) == .success, "fixture refresh reaches its controlled in-flight state")
        check(blockingController.requestTermination() == .terminateLater, "quit waits for an in-flight operation")
        blocking.allowRefresh.signal()
        check(blocking.refreshFinished.wait(timeout: .now() + 1) == .success, "fixture refresh completes after its gate opens")
        waitForMainQueue()
        check(blockingController.requestTermination() == .terminateNow, "quit can complete after the in-flight operation finishes")

        let reordering = ReorderingDiscoveryAdapter()
        let controller = MainWindowController(model: AppModel(adapter: reordering), isDemo: true)
        controller.loadInitialState()
        check(reordering.refreshFinished.wait(timeout: .now() + 1) == .success, "fixture window finishes its initial refresh")
        waitForMainQueue()
        let discover = NSSelectorFromString("discover")
        controller.perform(discover)
        check(reordering.discoveryFinished.wait(timeout: .now() + 1) == .success, "fixture window completes the first discovery")
        waitForMainQueue()
        controller.perform(NSSelectorFromString("showSetup"))
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        guard let popup = controller.window.flatMap({ pairedSpeakerPopup(in: $0.contentView ?? NSView()) }) else {
            check(false, "fixture window exposes the paired-speaker picker")
            print("\(passed) tests passed; \(failed) tests failed")
            exit(1)
        }
        popup.selectItem(at: 1)
        controller.perform(discover)
        check(reordering.discoveryFinished.wait(timeout: .now() + 1) == .success, "fixture window completes reordered discovery")
        waitForMainQueue()
        check(popup.selectedItem?.title.contains("11-22-33-44-55-66") == true, "reordered discovery preserves the selected speaker address")

        print("\(passed) tests passed; \(failed) tests failed")
        exit(failed == 0 ? 0 : 1)
    }
}
