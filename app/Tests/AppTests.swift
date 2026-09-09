import Foundation
import Darwin

private var passed = 0
private var failed = 0

private func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() { passed += 1; print("ok - \(name)") }
    else { failed += 1; print("not ok - \(name)") }
}

private func plist(_ values: [String: Any]) -> Data {
    try! PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
}

private final class MockRunner: ProcessRunning {
    var commands: [(String, [String])] = []
    var blueutilAvailable = true
    var watcherData: Data?
    var discoveryFails = false
    var setupFails = false
    var serviceRunning = false
    var loadedFailure = false
    var serviceReport: String?

    func run(executable: URL, arguments: [String], environment: [String: String]?, timeout: TimeInterval) throws -> ProcessResult {
        commands.append((executable.lastPathComponent, arguments))
        if executable.lastPathComponent == "install.sh" && arguments == ["--gui-status-plist"] {
            return ProcessResult(status: 0, stdout: plist([
                "schema": 1, "config_state": "valid", "config_error": "",
                "device_address": "AA-BB-CC-DD-EE-FF", "configured_blueutil_path": "/fake/blueutil",
                "detected_blueutil_path": blueutilAvailable ? "/fake/blueutil" : "", "blueutil_available": blueutilAvailable,
                "reconnect_mode": "source", "source_kind": "thunderbolt",
                "source_key": String(repeating: "a", count: 64), "source_label": "Test Dock",
                "current_power": "ac", "current_source": "match"
            ]), stderr: Data())
        }
        if executable.path == "/bin/launchctl" && arguments.first == "print" {
            if let report = serviceReport {
                return ProcessResult(status: 0, stdout: Data(report.utf8), stderr: Data())
            }
            if loadedFailure {
                return ProcessResult(status: 0, stdout: Data("state = waiting\nlast exit code = 78\n".utf8), stderr: Data())
            }
            return ProcessResult(status: serviceRunning ? 0 : 1, stdout: serviceRunning ? Data("state = running\npid = 123\n".utf8) : Data(), stderr: Data())
        }
        if executable.lastPathComponent == "watch-power" {
            return ProcessResult(status: 0, stdout: watcherData ?? plist([
                "schema": 1, "state_valid": false, "observed_at": 0, "phase": "idle", "attempts": 0,
                "next_attempt": 0, "window_deadline": 0, "last_power": "unknown", "last_source": "unknown",
                "departure_observed": false
            ]), stderr: Data())
        }
        if executable.lastPathComponent == "blueutil" {
            return ProcessResult(status: 0, stdout: Data("[{\"name\":\"Speaker\",\"address\":\"aa-bb-cc-dd-ee-ff\",\"connected\":false},{\"name\":\"Duplicate\",\"address\":\"aa-bb-cc-dd-ee-ff\",\"connected\":false}]".utf8), stderr: Data())
        }
        if executable.lastPathComponent == "install.sh" && arguments == ["--discover"] {
            return ProcessResult(status: discoveryFails ? 2 : 0, stdout: Data("1\tthunderbolt\tTest Dock\t\(String(repeating: "a", count: 64))\n".utf8), stderr: discoveryFails ? Data("Hardware discovery failed".utf8) : Data())
        }
        if executable.lastPathComponent == "install.sh" {
            return ProcessResult(status: setupFails ? 1 : 0, stdout: Data("Preview complete".utf8), stderr: setupFails ? Data("blueutil is required; install it with Homebrew: brew install blueutil".utf8) : Data())
        }
        if executable.path == "/bin/launchctl" {
            return ProcessResult(status: 0, stdout: Data(), stderr: Data())
        }
        return ProcessResult(status: 127, stdout: Data(), stderr: Data("unexpected command".utf8))
    }
}

private final class ModelAdapter: ServiceAdapting {
    var refreshes = 0
    var mutations = 0
    var logsDirectory = URL(fileURLWithPath: "/tmp")
    func refresh() throws -> AppSnapshot { refreshes += 1; return .loading }
    func pairedSpeakers() throws -> [PairedSpeaker] { [] }
    func discoverSources() throws -> [SourceCandidate] { [] }
    func preview(address: String, rule: RuleChoice) throws -> String { "preview" }
    func apply(address: String, rule: RuleChoice) throws -> String { mutations += 1; return "apply" }
    func start() throws { mutations += 1 }
    func stop() throws { mutations += 1 }
}

@main
private enum AppTests {
    static func main() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uncordex-app-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = root.appendingPathComponent("Service")
        let launchAgent = root.appendingPathComponent("service.plist")
        try! FileManager.default.createDirectory(at: service, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: launchAgent.path, contents: Data())
        let paths = ServicePaths(serviceRoot: service, launchAgent: launchAgent, logsDirectory: root)

        let missing = MockRunner(); missing.blueutilAvailable = false
        let missingAdapter = ServiceAdapter(runner: missing, paths: paths)
        let missingSnapshot = try! missingAdapter.refresh()
        check(!missingSnapshot.blueutilAvailable, "missing blueutil is explicit")
        do { _ = try missingAdapter.pairedSpeakers(); check(false, "missing dependency blocks paired-device query") }
        catch { check(error.localizedDescription.contains("brew install blueutil"), "missing dependency has setup instructions") }

        let malformed = MockRunner(); malformed.watcherData = Data("not a plist".utf8)
        let malformedSnapshot = try! ServiceAdapter(runner: malformed, paths: paths).refresh()
        check(malformedSnapshot.watcher == nil && malformedSnapshot.watcherError.contains("unavailable"), "malformed watcher state is reported")

        let noState = MockRunner()
        let noStateSnapshot = try! ServiceAdapter(runner: noState, paths: paths).refresh()
        check(noStateSnapshot.watcher?.isValid == false, "missing watcher state is not presented as an observation")

        let discovery = MockRunner(); let discoveryAdapter = ServiceAdapter(runner: discovery, paths: paths); _ = try! discoveryAdapter.refresh(); discovery.discoveryFails = true
        do { _ = try discoveryAdapter.discoverSources(); check(false, "discovery failure propagates") }
        catch { check(error.localizedDescription.contains("Hardware discovery failed"), "discovery failure remains actionable") }

        let setup = MockRunner(); let setupAdapter = ServiceAdapter(runner: setup, paths: paths); _ = try! setupAdapter.refresh(); setup.setupFails = true
        do { _ = try setupAdapter.apply(address: "AA-BB-CC-DD-EE-FF", rule: .anyPower); check(false, "setup failure propagates") }
        catch { check(error.localizedDescription.contains("brew install blueutil"), "dependency disappearance at apply time is displayed") }
        check(setup.commands.contains(where: { $0.1.contains("--no-install-dependencies") }), "app setup forbids dependency installation at execution time")

        let controls = MockRunner(); let controlsAdapter = ServiceAdapter(runner: controls, paths: paths); _ = try! controlsAdapter.refresh()
        try! controlsAdapter.start(); try! controlsAdapter.stop()
        check(controls.commands.contains(where: { $0.1.first == "bootstrap" }), "start bootstraps the canonical LaunchAgent")
        check(controls.commands.contains(where: { $0.1.first == "bootout" }), "stop boots out without deleting configuration")

        let nested = MockRunner()
        nested.serviceReport = "gui/501/test = {\n\tstate = running\n\tresource coalition = {\n\t\tstate = active\n\t}\n\tjetsam coalition = {\n\t\tstate = active\n\t}\n}\n"
        let nestedSnapshot = try! ServiceAdapter(runner: nested, paths: paths).refresh()
        check(nestedSnapshot.service == .running, "nested coalition state does not override running service")
        nested.serviceReport = "gui/501/test = {\n\tstate = waiting\n\tlast exit code = 78\n\tresource coalition = {\n\t\tstate = running\n\t\tlast exit code = 0\n\t}\n}\n"
        let nestedFailure = try! ServiceAdapter(runner: nested, paths: paths).refresh()
        if case .loadedNotRunning(let detail) = nestedFailure.service {
            check(detail.contains("waiting") && detail.contains("78"), "nested state and exit code cannot hide a failed service")
        } else { check(false, "nested state and exit code cannot hide a failed service") }

        let failedJob = MockRunner(); failedJob.loadedFailure = true
        let failedAdapter = ServiceAdapter(runner: failedJob, paths: paths)
        let failedSnapshot = try! failedAdapter.refresh()
        if case .loadedNotRunning(let detail) = failedSnapshot.service { check(detail.contains("78"), "loaded failed job is distinct from running") }
        else { check(false, "loaded failed job is distinct from running") }
        try! failedAdapter.start(); try! failedAdapter.stop()
        check(failedJob.commands.contains(where: { $0.1.starts(with: ["kickstart", "-k"]) }), "loaded failed job can be restarted")
        check(failedJob.commands.contains(where: { $0.1.first == "bootout" }), "loaded failed job can be stopped")

        check(explicitRuleChoice(popupIndex: 0, choices: [.anyPower, .disconnectOnly]) == nil, "empty setup requires explicit rule selection")
        check(explicitRuleChoice(popupIndex: 1, choices: [.anyPower, .disconnectOnly]) == .anyPower, "explicit rule selection maps without broadening")

        let modelAdapter = ModelAdapter(); let model = AppModel(adapter: modelAdapter)
        check(modelAdapter.refreshes == 0 && modelAdapter.mutations == 0, "model initialization performs no I/O")
        try! model.refresh(); model.quit()
        check(modelAdapter.refreshes == 1 && modelAdapter.mutations == 0, "launch refresh and quit perform no mutations")

        let runner = SystemProcessRunner()
        let started = Date()
        do {
            _ = try runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["2"], environment: nil, timeout: 0.05)
            check(false, "process timeout is enforced")
        } catch {
            check(Date().timeIntervalSince(started) < 1.8, "process timeout is enforced")
        }

        let largeScript = "i=0; while [ $i -lt 7000 ]; do printf 'stdout-%04d-abcdefghijklmnopqrstuvwxyz\\n' $i; printf 'stderr-%04d-abcdefghijklmnopqrstuvwxyz\\n' $i >&2; i=$((i + 1)); done"
        let large = try! runner.run(executable: URL(fileURLWithPath: "/bin/bash"), arguments: ["-c", largeScript], environment: nil, timeout: 8)
        check(large.status == 0 && large.stdout.count > 200_000 && large.stderr.count > 200_000, "large simultaneous stdout and stderr are fully drained")

        let childPIDFile = root.appendingPathComponent("held-pipe-child.pid")
        let heldPipeScript = "sleep 5 & child=$!; printf '%s' $child > \"$1\"; printf held-pipe-parent-done"
        let heldStarted = Date()
        let held = try! runner.run(executable: URL(fileURLWithPath: "/bin/bash"), arguments: ["-c", heldPipeScript, "_", childPIDFile.path], environment: nil, timeout: 2)
        let childPID = Int32((try? String(contentsOf: childPIDFile).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "") ?? 0
        check(held.stdoutText == "held-pipe-parent-done" && Date().timeIntervalSince(heldStarted) < 1.5, "descendant-held pipes cannot extend the run")
        usleep(100_000)
        check(childPID > 0 && kill(childPID, 0) != 0, "descendant holding pipes is cancelled and cleaned up")

        print("\(passed) tests passed; \(failed) tests failed")
        exit(failed == 0 ? 0 : 1)
    }
}
