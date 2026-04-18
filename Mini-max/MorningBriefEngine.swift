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

    private init() {}

    func load() async {
        let today = Calendar.current.startOfDay(for: Date())
        if let stored = UserDefaults.standard.string(forKey: dateKey),
           let storedDate = ISO8601DateFormatter().date(from: stored),
           Calendar.current.isDate(storedDate, inSameDayAs: today),
           let data = UserDefaults.standard.data(forKey: itemsKey),
           let cached = try? JSONDecoder().decode([BriefItem].self, from: data),
           !cached.isEmpty {
            await MainActor.run { self.items = cached }
            return
        }

        await MainActor.run { self.isLoading = true; self.error = nil }
        do {
            let fetched = try await fetchAndSummarise()
            let encoded = try? JSONEncoder().encode(fetched)
            UserDefaults.standard.set(ISO8601DateFormatter().string(from: today), forKey: dateKey)
            if let encoded { UserDefaults.standard.set(encoded, forKey: itemsKey) }
            await MainActor.run { self.items = fetched; self.isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }

    private func fetchAndSummarise() async throws -> [BriefItem] {
        // 1. Fetch HN front page
        let hnURL = URL(string: "https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=8")!
        let (hnData, _) = try await URLSession.shared.data(from: hnURL)
        guard let hnJSON = try? JSONDecoder().decode(HNResponse.self, from: hnData) else {
            throw BriefError.hnDecodeFailed
        }
        let hits = hnJSON.hits.prefix(8)
        let titlesBlock = hits.map { $0.title }.joined(separator: "\n")

        // 2. Ask Claude to summarise
        let key = UserDefaults.standard.string(forKey: "minimax.claude.apiKey") ?? ""
        guard !key.isEmpty else { throw BriefError.missingKey }
        let model = UserDefaults.standard.string(forKey: "minimax.claude.model") ?? "claude-sonnet-4-5"

        let prompt = """
        You are a developer morning brief assistant. Given these Hacker News headlines, \
        pick the 3 most interesting for developers and rewrite each as a single concise sentence \
        (max 12 words). Return exactly 3 lines, no numbering, no preamble.

        Headlines:
        \(titlesBlock)
        """

        let body = SimpleClaude(model: model, max_tokens: 200,
                                messages: [SimpleMsg(role: "user", content: prompt)])
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
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

        // 3. Build BriefItems — match each summary line to nearest hit's timestamp
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)

        let iso = ISO8601DateFormatter()
        return lines.enumerated().map { idx, line in
            let hit = hits.indices.contains(idx) ? hits[idx] : nil
            let age: String = {
                guard let createdAt = hit?.created_at,
                      let date = iso.date(from: createdAt) else { return "" }
                let secs = Int(Date().timeIntervalSince(date))
                if secs < 3600 { return "\(secs / 60)m ago" }
                if secs < 86400 { return "\(secs / 3600)h ago" }
                return "\(secs / 86400)d ago"
            }()
            return BriefItem(source: "HN", title: line, timeAgo: age)
        }
    }
}

// MARK: - HN wire types

private struct HNResponse: Decodable {
    let hits: [HNHit]
}

private struct HNHit: Decodable {
    let title: String
    let created_at: String?
}

// MARK: - Minimal Claude wire types (no tools)

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

// MARK: - Errors

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
