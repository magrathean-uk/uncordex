import Foundation

final class FixtureServiceAdapter: ServiceAdapting {
    private let longContent: Bool
    private let emptySetup: Bool
    private var running = true
    var logsDirectory: URL { URL(fileURLWithPath: "/Users/demo/Library/Logs") }

    init(longContent: Bool = false, emptySetup: Bool = false) {
        self.longContent = longContent
        self.emptySetup = emptySetup
    }

    func refresh() throws -> AppSnapshot {
        AppSnapshot(
            service: emptySetup ? .notInstalled : (longContent ? .stopped : (running ? .running : .stopped)),
            configState: emptySetup ? "missing" : "valid",
            configError: emptySetup ? "No saved configuration. Choose a paired speaker and reconnection rule." : "",
            deviceAddress: emptySetup ? "" : "02-00-00-00-00-01",
            reconnectMode: emptySetup ? "" : "source", sourceKind: emptySetup ? "" : "thunderbolt",
            sourceKey: emptySetup ? "" : String(repeating: "a", count: 64),
            sourceLabel: emptySetup ? "" : (longContent ? "Thunderbolt Studio Display Dock in the shared production workspace" : "Studio Display Dock"),
            currentPower: "ac", currentSource: emptySetup ? "unknown" : "match", blueutilAvailable: true,
            blueutilPath: "/opt/homebrew/bin/blueutil",
            watcher: emptySetup ? nil : WatcherStatus(
                isValid: true, observedAt: Date().addingTimeInterval(-8), phase: longContent ? "paused" : "pending",
                attempts: 2, lastPower: "ac", lastSource: "match", departureObserved: false
            ),
            watcherError: longContent ? "Cached watcher details could not be refreshed because the configured dependency disappeared after the last observation. Reinstall blueutil, apply setup, then refresh." : ""
        )
    }

    func pairedSpeakers() throws -> [PairedSpeaker] {
        [PairedSpeaker(name: "Bose SoundLink Max", address: "02-00-00-00-00-01", connected: false)]
    }

    func discoverSources() throws -> [SourceCandidate] {
        [SourceCandidate(kind: "thunderbolt", label: longContent ? "Thunderbolt Studio Display Dock in the shared production workspace" : "Studio Display Dock", key: String(repeating: "a", count: 64))]
    }

    func preview(address: String, rule: RuleChoice) throws -> String { "Preview: \(rule.title) for \(address). No changes were made." }
    func apply(address: String, rule: RuleChoice) throws -> String { "Fixture setup applied." }
    func start() throws { running = true }
    func stop() throws { running = false }
}
