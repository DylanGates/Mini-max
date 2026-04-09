import Foundation
import Observation

// MARK: - Provider

enum AIProvider: String, CaseIterable, Codable {
    case claude = "claude"
    case openai = "openai"  // OpenAI-compatible: GPT-4, Ollama, LM Studio, etc.
}

// MARK: - Error

enum InsightError: Error, LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:           return "[insight] API key missing — add key in Settings"
        case .networkError(let e):     return "[insight] network error — \(e.localizedDescription)"
        case .invalidResponse(let c):  return "[insight] unexpected status \(c) from API"
        case .decodingError:           return "[insight] failed to parse API response"
        }
    }
}

// MARK: - Claude wire types

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
}
private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}
private struct ClaudeResponse: Decodable {
    let content: [ClaudeContent]
}
private struct ClaudeContent: Decodable {
    let text: String
}

// MARK: - OpenAI-compatible wire types

private struct OAIRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [OAIMessage]
}
private struct OAIMessage: Codable {
    let role: String
    let content: String
}
private struct OAIResponse: Decodable {
    let choices: [OAIChoice]
}
private struct OAIChoice: Decodable {
    let message: OAIMessage
}

// MARK: - InsightEngine

@Observable
@MainActor
final class InsightEngine {
    static let shared = InsightEngine()

    var isLoading  = false
    var lastError: InsightError? = nil

    // UserDefaults keys
    static let claudeKeyUD   = "minimax.claude.apiKey"
    static let openAIKeyUD   = "minimax.openai.apiKey"
    static let openAIBaseUD  = "minimax.openai.baseURL"    // default: https://api.openai.com
    static let claudeModelUD = "minimax.claude.model"      // default: claude-sonnet-4-5
    static let openAIModelUD = "minimax.openai.model"      // default: gpt-4o
    static let providerUD    = "minimax.insight.provider"  // AIProvider.rawValue

    private let cacheTTL     : TimeInterval = 300
    private let cacheKey     = "minimax.insight.cache"
    private let cacheTimeKey = "minimax.insight.cacheTime"

    // Current provider — reads from UserDefaults, defaults to Claude
    var provider: AIProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: Self.providerUD) ?? ""
            return AIProvider(rawValue: raw) ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.providerUD)
        }
    }

    private init() {}

    // MARK: - Public API

    func fetch(for tab: NotchTab) async throws -> String {
        if let cached = cachedInsight(for: tab) { return cached }
        return try await callAPI(prompt: prompt(for: tab), tab: tab)
    }

    func regenerate(for tab: NotchTab) async throws -> String {
        return try await callAPI(prompt: prompt(for: tab), tab: tab)
    }

    // MARK: - Dispatch

    private func callAPI(prompt text: String, tab: NotchTab) async throws -> String {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let result: String
            switch provider {
            case .claude: result = try await callClaude(prompt: text)
            case .openai: result = try await callOpenAI(prompt: text)
            }
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            cacheInsight(trimmed, for: tab)
            return trimmed
        } catch let e as InsightError {
            lastError = e
            throw e
        } catch {
            let e = InsightError.networkError(error)
            lastError = e
            throw e
        }
    }

    // MARK: - Claude

    private func callClaude(prompt text: String) async throws -> String {
        let key = UserDefaults.standard.string(forKey: Self.claudeKeyUD) ?? ""
        guard !key.isEmpty else { throw InsightError.missingAPIKey }

        let model = UserDefaults.standard.string(forKey: Self.claudeModelUD)
                    ?? "claude-sonnet-4-5"

        let body = ClaudeRequest(
            model: model,
            max_tokens: 120,
            messages: [ClaudeMessage(role: "user", content: text)]
        )
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw InsightError.invalidResponse(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(ClaudeResponse.self, from: data),
              let content = decoded.content.first?.text else {
            throw InsightError.decodingError
        }
        return content
    }

    // MARK: - OpenAI-compatible (GPT-4, Ollama, LM Studio, etc.)

    private func callOpenAI(prompt text: String) async throws -> String {
        // Ollama and local servers don't need a key — fall through with empty key
        let key   = UserDefaults.standard.string(forKey: Self.openAIKeyUD) ?? ""
        let base  = UserDefaults.standard.string(forKey: Self.openAIBaseUD)
                    ?? "https://api.openai.com"
        let model = UserDefaults.standard.string(forKey: Self.openAIModelUD)
                    ?? "gpt-4o"

        // Local servers (Ollama) have no key — remote OpenAI requires one
        let isLocal = base.contains("localhost") || base.contains("127.0.0.1")
        guard isLocal || !key.isEmpty else { throw InsightError.missingAPIKey }

        let body = OAIRequest(
            model: model,
            max_tokens: 120,
            messages: [OAIMessage(role: "user", content: text)]
        )
        var req = URLRequest(url: URL(string: "\(base)/v1/chat/completions")!)
        req.httpMethod = "POST"
        if !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw InsightError.invalidResponse(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(OAIResponse.self, from: data),
              let content = decoded.choices.first?.message.content else {
            throw InsightError.decodingError
        }
        return content
    }

    // MARK: - Cache

    private func cachedInsight(for tab: NotchTab) -> String? {
        let k = tab.cacheKey
        guard let times = cachedTimes(), let ts = times[k],
              Date().timeIntervalSince1970 - ts < cacheTTL,
              let texts = cachedTexts(), let text = texts[k]
        else { return nil }
        return text
    }

    private func cacheInsight(_ text: String, for tab: NotchTab) {
        let k = tab.cacheKey
        var texts = cachedTexts() ?? [:]
        var times = cachedTimes() ?? [:]
        texts[k] = text
        times[k] = Date().timeIntervalSince1970
        if let d = try? JSONEncoder().encode(texts) { UserDefaults.standard.set(d, forKey: cacheKey) }
        if let d = try? JSONEncoder().encode(times) { UserDefaults.standard.set(d, forKey: cacheTimeKey) }
    }

    private func cachedTexts() -> [String: String]? {
        guard let d = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: d)
    }

    private func cachedTimes() -> [String: Double]? {
        guard let d = UserDefaults.standard.data(forKey: cacheTimeKey) else { return nil }
        return try? JSONDecoder().decode([String: Double].self, from: d)
    }

    // MARK: - Placeholder prompts (replaced by context builders in Plan 01-02)

    private func prompt(for tab: NotchTab) -> String {
        switch tab {
        case .focus:    return "Give one brief insight about focus and productivity. One sentence only."
        case .projects: return "Give one brief insight about software projects and momentum. One sentence only."
        case .tasks:    return "Give one brief insight about task management and prioritization. One sentence only."
        case .streak:   return "Give one brief insight about consistency and building habits. One sentence only."
        case .home:     return "Give one brief encouraging insight to start the day well. One sentence only."
        case .learn:    return "Give one brief insight about learning and skill development. One sentence only."
        }
    }
}

// MARK: - NotchTab cache key

extension NotchTab {
    var cacheKey: String {
        switch self {
        case .home:     return "home"
        case .projects: return "projects"
        case .streak:   return "streak"
        case .learn:    return "learn"
        case .tasks:    return "tasks"
        case .focus:    return "focus"
        }
    }
}
