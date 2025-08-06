import Foundation

struct AnalyticsEvent: Codable {
    let type: String // "open", "close", etc.
    let timestamp: Date
}

struct ContextAnalytics: Codable {
    var events: [AnalyticsEvent]
    var openCount: Int
}

struct AnalyticsStore: Codable {
    var contexts: [String: ContextAnalytics] = [:]
    var contextCreatedCount: Int = 0
    // Add other top-level stats here in the future
}

class AnalyticsManager: ContextManagerListener, ObservableObject {
    @Published private(set) var store = AnalyticsStore()
    private let maxEvents = 50
    private let analyticsFileURL: URL
    
    init(contextsFileURL: URL) {
        let analyticsURL = contextsFileURL.deletingLastPathComponent().appendingPathComponent("analytics.json")
        self.analyticsFileURL = analyticsURL
        loadAnalytics()
    }
    
    func contextDidOpen(contextID: UUID) {
        let key = contextID.uuidString
        var contextData = store.contexts[key] ?? ContextAnalytics(events: [], openCount: 0)
        contextData.openCount += 1
        addEvent(type: "open", contextID: contextID, contextData: &contextData)
        store.contexts[key] = contextData
        saveAnalytics()
    }
    
    func contextDidClose(contextID: UUID) {
        let key = contextID.uuidString
        var contextData = store.contexts[key] ?? ContextAnalytics(events: [], openCount: 0)
        addEvent(type: "close", contextID: contextID, contextData: &contextData)
        store.contexts[key] = contextData
        saveAnalytics()
    }
    
    func contextDidCreate(contextID: UUID) {
        store.contextCreatedCount += 1
        saveAnalytics()
    }

    func contextsLoaded(_ contexts: [Context]) {
    }

    func contextsSaved(_ contexts: [Context]) {
    }

    private func addEvent(type: String, contextID: UUID, contextData: inout ContextAnalytics) {
        let event = AnalyticsEvent(type: type, timestamp: Date())
        contextData.events.append(event)
        if contextData.events.count > maxEvents {
            contextData.events.removeFirst(contextData.events.count - maxEvents)
        }
    }
    
    // Utility methods for querying analytics
    func getEvents(for contextID: UUID, type: String? = nil) -> [AnalyticsEvent] {
        let key = contextID.uuidString
        guard let contextData = store.contexts[key] else { return [] }
        return contextData.events.filter { type == nil || $0.type == type }
    }
    func getOpenCount(for contextID: UUID) -> Int {
        let key = contextID.uuidString
        return store.contexts[key]?.openCount ?? 0
    }
    func getLastOpenEvents(for contextID: UUID) -> [Date] {
        getEvents(for: contextID, type: "open").map { $0.timestamp }
    }
    func getLastCloseEvents(for contextID: UUID) -> [Date] {
        getEvents(for: contextID, type: "close").map { $0.timestamp }
    }
    
    private func saveAnalytics() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(store)
            try encoded.write(to: analyticsFileURL)
        } catch {
            print("Failed to save analytics: \(error)")
        }
    }
    
    private func loadAnalytics() {
        do {
            let data = try Data(contentsOf: analyticsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.store = try decoder.decode(AnalyticsStore.self, from: data)
        } catch {
            // No analytics file yet or failed to read
        }
    }
}
