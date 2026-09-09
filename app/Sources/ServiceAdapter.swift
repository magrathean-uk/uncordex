import Foundation
import Darwin

protocol ServiceAdapting: AnyObject {
    func refresh() throws -> AppSnapshot
    func pairedSpeakers() throws -> [PairedSpeaker]
    func discoverSources() throws -> [SourceCandidate]
    func preview(address: String, rule: RuleChoice) throws -> String
    func apply(address: String, rule: RuleChoice) throws -> String
    func start() throws
    func stop() throws
    var logsDirectory: URL { get }
}

struct ServicePaths {
    let serviceRoot: URL
    let launchAgent: URL
    let logsDirectory: URL

    static func bundled() -> ServicePaths {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        return ServicePaths(
            serviceRoot: resources.appendingPathComponent("Service"),
            launchAgent: home.appendingPathComponent("Library/LaunchAgents/uk.magrathean.uncordex.watch-power.plist"),
            logsDirectory: home.appendingPathComponent("Library/Logs")
        )
    }
}

enum AdapterError: LocalizedError {
    case command(String)
    case malformed(String)
    case invalidAddress
    case missingBlueutil

    var errorDescription: String? {
        switch self {
        case .command(let message): return message
        case .malformed(let message): return message
        case .invalidAddress: return "Enter a Bluetooth address like AA-BB-CC-DD-EE-FF."
        case .missingBlueutil: return "blueutil is missing. Install it with Homebrew: brew install blueutil"
        }
    }
}

final class ServiceAdapter: ServiceAdapting {
    private let runner: ProcessRunning
    private let paths: ServicePaths
    private let files: FileManager
    private var latestStatus: GUIStatusPayload?
    private let decoder = PropertyListDecoder()
    private let mutationLock = NSLock()
    private var mutationInFlight = false
    private var latestService: ServiceAvailability = .notInstalled

    init(runner: ProcessRunning = SystemProcessRunner(), paths: ServicePaths = .bundled(), files: FileManager = .default) {
        self.runner = runner
        self.paths = paths
        self.files = files
    }

    var logsDirectory: URL { paths.logsDirectory }

    func refresh() throws -> AppSnapshot {
        let statusResult = try command(paths.serviceRoot.appendingPathComponent("install.sh"), ["--gui-status-plist"], timeout: 35)
        let payload: GUIStatusPayload
        do { payload = try decoder.decode(GUIStatusPayload.self, from: statusResult.stdout) }
        catch { throw AdapterError.malformed("The service returned an unreadable configuration status.") }
        guard payload.schema == 1 else { throw AdapterError.malformed("The service status schema is unsupported.") }
        latestStatus = payload

        let uid = String(getuid())
        let printResult = try runner.run(
            executable: URL(fileURLWithPath: "/bin/launchctl"),
            arguments: ["print", "gui/\(uid)/uk.magrathean.uncordex.watch-power"],
            environment: nil,
            timeout: 5
        )
        let service = serviceAvailability(from: printResult)
        latestService = service

        var watcher: WatcherStatus?
        var watcherError = ""
        if payload.configState == "valid" && payload.blueutilAvailable {
            do {
                let watcherResult = try command(paths.serviceRoot.appendingPathComponent("watch-power"), ["--status-plist"], timeout: 12)
                let status = try decoder.decode(WatcherStatusPayload.self, from: watcherResult.stdout)
                guard status.schema == 1 else { throw AdapterError.malformed("Unsupported watcher status schema.") }
                watcher = WatcherStatus(
                    isValid: status.stateValid,
                    observedAt: status.observedAt > 0 ? Date(timeIntervalSince1970: TimeInterval(status.observedAt)) : nil,
                    phase: status.phase,
                    attempts: status.attempts,
                    lastPower: status.lastPower,
                    lastSource: status.lastSource,
                    departureObserved: status.departureObserved
                )
            } catch {
                watcherError = "Cached watcher status is unavailable: \(error.localizedDescription)"
            }
        }

        let blueutilPath = payload.detectedBlueutilPath.isEmpty ? payload.configuredBlueutilPath : payload.detectedBlueutilPath
        return AppSnapshot(
            service: service, configState: payload.configState, configError: payload.configError,
            deviceAddress: payload.deviceAddress, reconnectMode: payload.reconnectMode,
            sourceKind: payload.sourceKind, sourceKey: payload.sourceKey, sourceLabel: payload.sourceLabel,
            currentPower: payload.currentPower, currentSource: payload.currentSource,
            blueutilAvailable: payload.blueutilAvailable, blueutilPath: blueutilPath,
            watcher: watcher, watcherError: watcherError
        )
    }

    func pairedSpeakers() throws -> [PairedSpeaker] {
        guard let status = latestStatus, status.blueutilAvailable else { throw AdapterError.missingBlueutil }
        let path = status.detectedBlueutilPath.isEmpty ? status.configuredBlueutilPath : status.detectedBlueutilPath
        guard !path.isEmpty else { throw AdapterError.missingBlueutil }
        let result = try command(URL(fileURLWithPath: path), ["--paired", "--format", "json"], timeout: 15)
        guard let objects = try? JSONSerialization.jsonObject(with: result.stdout) as? [[String: Any]] else {
            throw AdapterError.malformed("blueutil returned an unreadable paired-device list.")
        }
        var seen = Set<String>()
        return objects.compactMap { item in
            guard let address = item["address"] as? String, !address.isEmpty, !seen.contains(address.lowercased()) else { return nil }
            seen.insert(address.lowercased())
            return PairedSpeaker(name: (item["name"] as? String) ?? "Bluetooth device", address: address.uppercased(), connected: (item["connected"] as? Bool) ?? false)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func discoverSources() throws -> [SourceCandidate] {
        let result = try command(paths.serviceRoot.appendingPathComponent("install.sh"), ["--discover"], timeout: 35)
        return result.stdoutText.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 4 else { return nil }
            return SourceCandidate(kind: String(fields[1]), label: String(fields[2]), key: String(fields[3]))
        }
    }

    func preview(address: String, rule: RuleChoice) throws -> String {
        try validate(address)
        return try command(paths.serviceRoot.appendingPathComponent("install.sh"), [address] + rule.installerArguments + ["--no-install-dependencies", "--dry-run"], timeout: 35).stdoutText
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(address: String, rule: RuleChoice) throws -> String {
        try withMutation {
            try validate(address)
            guard latestStatus?.blueutilAvailable == true else { throw AdapterError.missingBlueutil }
            return try command(paths.serviceRoot.appendingPathComponent("install.sh"), [address] + rule.installerArguments + ["--no-install-dependencies"], timeout: 60).stdoutText
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func start() throws {
        try withMutation {
            let domain = "gui/\(getuid())"
            switch latestService {
            case .loadedNotRunning:
                _ = try command(URL(fileURLWithPath: "/bin/launchctl"), ["kickstart", "-k", "\(domain)/uk.magrathean.uncordex.watch-power"], timeout: 15)
            default:
                guard files.fileExists(atPath: paths.launchAgent.path) else { throw AdapterError.command("Apply setup before starting the service.") }
                _ = try command(URL(fileURLWithPath: "/bin/launchctl"), ["bootstrap", domain, paths.launchAgent.path], timeout: 15)
            }
        }
    }

    func stop() throws {
        try withMutation {
            _ = try command(URL(fileURLWithPath: "/bin/launchctl"), ["bootout", "gui/\(getuid())", paths.launchAgent.path], timeout: 15)
        }
    }

    private func validate(_ address: String) throws {
        let pattern = "^[0-9A-Fa-f]{2}([:-][0-9A-Fa-f]{2}){5}$"
        guard address.range(of: pattern, options: .regularExpression) != nil else { throw AdapterError.invalidAddress }
    }

    private func command(_ executable: URL, _ arguments: [String], timeout: TimeInterval) throws -> ProcessResult {
        let result = try runner.run(executable: executable, arguments: arguments, environment: nil, timeout: timeout)
        guard result.status == 0 else {
            let detail = result.stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AdapterError.command(detail.isEmpty ? "\(executable.lastPathComponent) failed with status \(result.status)." : detail)
        }
        return result
    }

    private func serviceAvailability(from result: ProcessResult) -> ServiceAvailability {
        guard result.status == 0 else { return files.fileExists(atPath: paths.launchAgent.path) ? .stopped : .notInstalled }
        var state = "unavailable"
        var lastExit: Int?
        var depth = 0
        for rawLine in result.stdoutText.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // launchctl also reports nested resource/ jetsam coalition states.
            // Only fields in the service dictionary describe the job itself.
            if line.hasSuffix("{") { depth += 1; continue }
            if line == "}" { depth = max(0, depth - 1); continue }
            guard depth <= 1 else { continue }
            if line.hasPrefix("state = ") { state = String(line.dropFirst("state = ".count)) }
            if line.hasPrefix("last exit code = ") { lastExit = Int(line.dropFirst("last exit code = ".count)) }
        }
        if state == "running" { return .running }
        var detail = "state: \(state)"
        if let lastExit, lastExit != 0 { detail += "; last exit: \(lastExit)" }
        return .loadedNotRunning(detail)
    }

    private func withMutation<T>(_ operation: () throws -> T) throws -> T {
        mutationLock.lock()
        if mutationInFlight {
            mutationLock.unlock()
            throw AdapterError.command("Another service change is already in progress.")
        }
        mutationInFlight = true
        mutationLock.unlock()
        defer {
            mutationLock.lock()
            mutationInFlight = false
            mutationLock.unlock()
        }
        return try operation()
    }
}
