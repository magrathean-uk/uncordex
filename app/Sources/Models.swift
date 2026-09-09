import Foundation

enum RuleChoice: Equatable {
    case savedSource(SourceCandidate)
    case anyPower
    case disconnectOnly

    var title: String {
        switch self {
        case .savedSource(let source): return "Saved source: \(source.label)"
        case .anyPower: return "Any external power"
        case .disconnectOnly: return "Disconnect only"
        }
    }

    var installerArguments: [String] {
        switch self {
        case .savedSource(let source): return ["--source", source.key]
        case .anyPower: return ["--any-power"]
        case .disconnectOnly: return ["--disconnect-only"]
        }
    }
}

struct SourceCandidate: Equatable {
    let kind: String
    let label: String
    let key: String
}

func explicitRuleChoice(popupIndex: Int, choices: [RuleChoice]) -> RuleChoice? {
    let choiceIndex = popupIndex - 1
    return choices.indices.contains(choiceIndex) ? choices[choiceIndex] : nil
}

struct PairedSpeaker: Equatable {
    let name: String
    let address: String
    let connected: Bool
}

enum ServiceAvailability: Equatable {
    case running
    case loadedNotRunning(String)
    case stopped
    case notInstalled

    var title: String {
        switch self {
        case .running: return "Running"
        case .loadedNotRunning(let detail): return "Loaded, not running — \(detail)"
        case .stopped: return "Stopped"
        case .notInstalled: return "Not installed"
        }
    }

    var canStart: Bool {
        switch self {
        case .stopped, .loadedNotRunning: return true
        case .running, .notInstalled: return false
        }
    }

    var canStop: Bool {
        switch self {
        case .running, .loadedNotRunning: return true
        case .stopped, .notInstalled: return false
        }
    }
}

struct WatcherStatus: Equatable {
    let isValid: Bool
    let observedAt: Date?
    let phase: String
    let attempts: Int
    let lastPower: String
    let lastSource: String
    let departureObserved: Bool
}

struct AppSnapshot: Equatable {
    let service: ServiceAvailability
    let configState: String
    let configError: String
    let deviceAddress: String
    let reconnectMode: String
    let sourceKind: String
    let sourceKey: String
    let sourceLabel: String
    let currentPower: String
    let currentSource: String
    let blueutilAvailable: Bool
    let blueutilPath: String
    let watcher: WatcherStatus?
    let watcherError: String

    static let loading = AppSnapshot(
        service: .notInstalled, configState: "loading", configError: "",
        deviceAddress: "", reconnectMode: "", sourceKind: "", sourceKey: "",
        sourceLabel: "", currentPower: "unknown", currentSource: "unknown",
        blueutilAvailable: false, blueutilPath: "", watcher: nil, watcherError: ""
    )
}

struct GUIStatusPayload: Decodable {
    let schema: Int
    let configState: String
    let configError: String
    let deviceAddress: String
    let configuredBlueutilPath: String
    let detectedBlueutilPath: String
    let blueutilAvailable: Bool
    let reconnectMode: String
    let sourceKind: String
    let sourceKey: String
    let sourceLabel: String
    let currentPower: String
    let currentSource: String

    enum CodingKeys: String, CodingKey {
        case schema
        case configState = "config_state"
        case configError = "config_error"
        case deviceAddress = "device_address"
        case configuredBlueutilPath = "configured_blueutil_path"
        case detectedBlueutilPath = "detected_blueutil_path"
        case blueutilAvailable = "blueutil_available"
        case reconnectMode = "reconnect_mode"
        case sourceKind = "source_kind"
        case sourceKey = "source_key"
        case sourceLabel = "source_label"
        case currentPower = "current_power"
        case currentSource = "current_source"
    }
}

struct WatcherStatusPayload: Decodable {
    let schema: Int
    let stateValid: Bool
    let observedAt: Int
    let phase: String
    let attempts: Int
    let lastPower: String
    let lastSource: String
    let departureObserved: Bool

    enum CodingKeys: String, CodingKey {
        case schema
        case stateValid = "state_valid"
        case observedAt = "observed_at"
        case phase, attempts
        case lastPower = "last_power"
        case lastSource = "last_source"
        case departureObserved = "departure_observed"
    }
}
