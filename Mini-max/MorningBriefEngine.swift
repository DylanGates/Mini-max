import Foundation
import Observation

struct BriefItem: Identifiable, Codable {
    let id: UUID
    let source: String
    let title: String
    let timeAgo: String

    init(id: UUID = UUID(), source: String, title: String, timeAgo: String) {
        self.id = id; self.source = source; self.title = title; self.timeAgo = timeAgo
    }
}

@Observable
final class MorningBriefEngine {
    static let shared = MorningBriefEngine()

    var items: [BriefItem] = []
    var isLoading = false
    var error: String?

    private let dateKey  = "minimax.brief.date"
    private let itemsKey = "minimax.brief.items"
    private let cacheTTL: TimeInterval = 1800 // 30 minutes for real-time feel

    private init() {}

    func load(force: Bool = false) async {
        if !force {
            if let data = UserDefaults.standard.data(forKey: itemsKey),
               let lastFetch = UserDefaults.standard.object(forKey: dateKey) as? Date,
               Date().timeIntervalSince(lastFetch) < cacheTTL,
               let cached = try? JSONDecoder().decode([BriefItem].self, from: data),
               !cached.isEmpty {
                await MainActor.run { self.items = cached }
                return
            }
        }

        await MainActor.run { self.isLoading = true; self.error = nil }
        do {
            let fetched = try await fetchAndSummarise()
            let encoded = try? JSONEncoder().encode(fetched)
            UserDefaults.standard.set(Date(), forKey: dateKey)
            if let encoded { UserDefaults.standard.set(encoded, forKey: itemsKey) }
            await MainActor.run { self.items = fetched; self.isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }

    private func fetchAndSummarise() async throws -> [BriefItem] {
        // 1. Fetch from multiple sources
        let newsService = RealTimeNewsService.shared
        let rawNews = await newsService.fetchAll()
        
        // 2. Fetch HN (with keywords)
        var hnHeadlines: [String] = []
        if let hnURL = URL(string: "https://hn.algolia.com/api/v1/search?query=swift+OR+macos+OR+fintech&tags=front_page&hitsPerPage=10") {
            if let (hnData, _) = try? await URLSession.shared.data(from: hnURL),
               let hnJSON = try? JSONDecoder().decode(HNResponse.self, from: hnData) {
                hnHeadlines = hnJSON.hits.map { $0.title }
            }
        }

        // 3. Fetch The Guardian (Fintech/Regional)
        var guardianHeadlines: [String] = []
        if let gURL = URL(string: "https://content.guardianapis.com/search?q=fintech%20OR%20ghana&api-key=test&page-size=5") {
            if let (gData, _) = try? await URLSession.shared.data(from: gURL),
               let gJSON = try? JSONDecoder().decode(GuardianResponse.self, from: gData) {
                guardianHeadlines = gJSON.response.results.map { $0.webTitle }
            }
        }

        // 4. Prepare prompt
        let allHeadlines = (
            rawNews.prefix(20).map { "[\($0.source)] \($0.title)" } + 
            hnHeadlines.prefix(5).map { "[HN] \($0)" } +
            guardianHeadlines.map { "[Guardian] \($0)" }
        ).joined(separator: "\n")

        let key = UserDefaults.standard.string(forKey: "minimax.claude.apiKey") ?? ""
        guard !key.isEmpty else { throw BriefError.missingKey }
        let model = UserDefaults.standard.string(forKey: "minimax.claude.model") ?? "claude-sonnet-4-5"

        let prompt = """
        You are a elite tech news analyst for a developer in the Ghana fintech ecosystem.
        From these headlines, pick the 7 most significant developments in global and regional tech.
        
        Prioritize:
        1. Swift/macOS/iOS breakthroughs.
        2. Global fintech shifts (payment rails, crypto, banking).
        3. Tech news specifically affecting West Africa/Ghana.
        4. Critical software engineering trends.

        Rewrite each as a punchy, high-density sentence (max 15 words).
        Precede each line with the source name in brackets, e.g., [TechCrunch], [HN], [Guardian].
        Return exactly 7 lines, no numbering.

        Headlines:
        \(allHeadlines)
        """

        let body = SimpleClaude(model: model, max_tokens: 400,
                                messages: [SimpleMsg(role: "user", content: prompt)])
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key,              forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",     forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONEncoder().encode(body)

        let (apiData, apiResp) = try await URLSession.shared.data(for: req)
        if let http = apiResp as? HTTPURLResponse, http.statusCode != 200 {
            throw BriefError.claudeStatus(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(SimpleClaudeResponse.self, from: apiData) else {
            throw BriefError.claudeDecodeFailed
        }
        
        let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.map { line in
            let parts = line.split(separator: "]", maxSplits: 1)
            let src = parts.count > 1 ? String(parts[0]).replacingOccurrences(of: "[", with: "") : "News"
            let title = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : line
            return BriefItem(source: src, title: title, timeAgo: "Live")
        }
    }
}

// MARK: - Wire Types

private struct GuardianResponse: Decodable {
    let response: GuardianResultWrapper
}

private struct GuardianResultWrapper: Decodable {
    let results: [GuardianResult]
}

private struct GuardianResult: Decodable {
    let webTitle: String
}

private struct HNResponse: Decodable {
    let hits: [HNHit]
}

private struct HNHit: Decodable {
    let title: String
}

private struct SimpleClaude: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [SimpleMsg]
}

private struct SimpleMsg: Encodable {
    let role: String
    let content: String
}

private struct SimpleClaudeResponse: Decodable {
    let content: [SimpleBlock]
}

private struct SimpleBlock: Decodable {
    let type: String
    let text: String?
}

private enum BriefError: Error, LocalizedError {
    case missingKey
    case hnDecodeFailed
    case claudeStatus(Int)
    case claudeDecodeFailed

    var errorDescription: String? {
        switch self {
        case .missingKey:         return "[brief] Claude API key not set"
        case .hnDecodeFailed:     return "[brief] could not parse HN response"
        case .claudeStatus(let c): return "[brief] Claude returned \(c)"
        case .claudeDecodeFailed: return "[brief] could not parse Claude response"
        }
    }
}
