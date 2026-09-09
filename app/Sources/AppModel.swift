import Foundation

final class AppModel {
    private let adapter: ServiceAdapting
    private(set) var snapshot: AppSnapshot = .loading
    private(set) var speakers: [PairedSpeaker] = []
    private(set) var sources: [SourceCandidate] = []

    init(adapter: ServiceAdapting) { self.adapter = adapter }

    func refresh() throws { snapshot = try adapter.refresh() }

    func discover() throws {
        speakers = try adapter.pairedSpeakers()
        sources = try adapter.discoverSources()
    }

    func preview(address: String, rule: RuleChoice) throws -> String { try adapter.preview(address: address, rule: rule) }
    func apply(address: String, rule: RuleChoice) throws -> String { try adapter.apply(address: address, rule: rule) }
    func start() throws { try adapter.start() }
    func stop() throws { try adapter.stop() }
    func quit() {}
    var logsDirectory: URL { adapter.logsDirectory }
}
