import Foundation
import Observation

// Contribution level 0–4 matching GitHub's heatmap scale
struct DayContribution {
    let date: Date
    let count: Int
    var level: Int {
        switch count {
        case 0:       return 0
        case 1...3:   return 1
        case 4...7:   return 2
        case 8...15:  return 3
        default:      return 4
        }
    }
}

@Observable
final class GitHubContributionStore {
    static let shared = GitHubContributionStore()

    // username → contributions by date string "YYYY-MM-DD"
    var contributionsByUser: [String: [String: DayContribution]] = [:]
    var fetchError: String? = nil
    var isFetching = false

    // Per-account tokens: username → PAT.
    // A per-account token includes private contributions for that account.
    // Falls back to globalToken for public-only data.
    private let perAccountKey = "minimax.github.perAccountTokens"  // [String:String] JSON
    private let cacheKey      = "minimax.github.contributionCache"
    private let cacheTimeKey  = "minimax.github.contributionCacheTime"
    private let cacheTTL: TimeInterval = 3600

    var perAccountTokens: [String: String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: perAccountKey),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONSerialization.data(withJSONObject: newValue) {
                UserDefaults.standard.set(data, forKey: perAccountKey)
            }
        }
    }

    func token(for username: String) -> String {
        perAccountTokens[username] ?? ""
    }

    func setToken(_ token: String, for username: String) {
        var tokens = perAccountTokens
        if token.isEmpty { tokens.removeValue(forKey: username) }
        else { tokens[username] = token }
        perAccountTokens = tokens
    }

    var hasAnyToken: Bool {
        !perAccountTokens.isEmpty
    }

    private init() {
        loadCache()
        if hasAnyToken {
            Task { await fetchAll() }
        }
    }

    // MARK: - Fetch

    func fetchAll() async {
        guard hasAnyToken else { return }
        await MainActor.run { isFetching = true; fetchError = nil }

        if let cacheTime = UserDefaults.standard.object(forKey: cacheTimeKey) as? Date,
           Date().timeIntervalSince(cacheTime) < cacheTTL,
           !contributionsByUser.isEmpty {
            await MainActor.run { isFetching = false }
            return
        }

        let accounts = GitHubAccountManager.shared.accounts
        var results: [String: [String: DayContribution]] = [:]

        for account in accounts {
            let pat = token(for: account.username)
            guard !pat.isEmpty else { continue }
            do {
                let data = try await fetchContributions(username: account.username, token: pat)
                results[account.username] = data
            } catch {
                await MainActor.run { fetchError = "\(account.username): \(error.localizedDescription)" }
            }
        }

        await MainActor.run {
            contributionsByUser = results
            isFetching = false
            saveCache(results)
            UserDefaults.standard.set(Date(), forKey: cacheTimeKey)
        }
    }

    func forceRefresh() async {
        UserDefaults.standard.removeObject(forKey: cacheTimeKey)
        await fetchAll()
    }

    // MARK: - GraphQL

    private func fetchContributions(username: String, token: String) async throws -> [String: DayContribution] {
        let cal = Calendar(identifier: .gregorian)
        guard let from = cal.date(byAdding: .day, value: -(16 * 7), to: Date()) else {
            return [:]
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let body: [String: Any] = [
            "query": "query($username: String!, $from: DateTime!, $to: DateTime!) { user(login: $username) { contributionsCollection(from: $from, to: $to) { contributionCalendar { weeks { contributionDays { contributionCount date } } } } } }",
            "variables": [
                "username": username,
                "from": formatter.string(from: from),
                "to": formatter.string(from: Date())
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try parseContributions(from: data)
    }

    private func parseContributions(from data: Data) throws -> [String: DayContribution] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any],
              let collection = user["contributionsCollection"] as? [String: Any],
              let calendar = collection["contributionCalendar"] as? [String: Any],
              let weeks = calendar["weeks"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }

        var result: [String: DayContribution] = [:]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")

        for week in weeks {
            guard let days = week["contributionDays"] as? [[String: Any]] else { continue }
            for day in days {
                guard let dateStr = day["date"] as? String,
                      let count = day["contributionCount"] as? Int,
                      let date = df.date(from: dateStr)
                else { continue }
                result[dateStr] = DayContribution(date: date, count: count)
            }
        }
        return result
    }

    // MARK: - Cache

    private func saveCache(_ data: [String: [String: DayContribution]]) {
        var flat: [String: [String: Int]] = [:]
        for (user, days) in data { flat[user] = days.mapValues(\.count) }
        if let encoded = try? JSONSerialization.data(withJSONObject: flat) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let flat = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Int]]
        else { return }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")

        var results: [String: [String: DayContribution]] = [:]
        for (user, days) in flat {
            var dayMap: [String: DayContribution] = [:]
            for (dateStr, count) in days {
                if let date = df.date(from: dateStr) {
                    dayMap[dateStr] = DayContribution(date: date, count: count)
                }
            }
            results[user] = dayMap
        }
        contributionsByUser = results
    }
}
