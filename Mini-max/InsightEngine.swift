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
    let messages: [ClaudeMsg]
    let tools: [MMTool]?
}

private struct ClaudeMsg: Encodable {
    let role: String
    let content: ClaudeMsgContent
}

private enum ClaudeMsgContent: Encodable {
    case text(String)
    case blocks([ClaudeMsgBlock])

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let s):     try s.encode(to: encoder)
        case .blocks(let arr): try arr.encode(to: encoder)
        }
    }
}

private struct ClaudeMsgBlock: Encodable {
    let type: String
    let tool_use_id: String?
    let content: String?
    let id: String?
    let name: String?
    let input: [String: String]?
}

private struct ClaudeResponse: Decodable {
    let content: [ClaudeContent]
    let stop_reason: String?
}

private struct ClaudeContent: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: String]?
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
    var currentTool: String? = nil

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

    // Store references — read-only, synchronous
    private let pomodoro  = PomodoroManager.shared
    private let projects  = ProjectStore.shared
    private let taskStore = TaskStore.shared
    private let learning  = LearningStore.shared
    private let github    = GitHubContributionStore.shared

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

    func fetch(for tab: NotchTab, verbose: Bool = false) async throws -> String {
        if let cached = cachedInsight(for: tab, verbose: verbose) { return cached }
        return try await callAPI(prompt: prompt(for: tab, verbose: verbose), tab: tab, verbose: verbose)
    }

    func regenerate(for tab: NotchTab, verbose: Bool = false) async throws -> String {
        return try await callAPI(prompt: prompt(for: tab, verbose: verbose), tab: tab, verbose: verbose)
    }

    // MARK: - Dispatch

    private func callAPI(prompt text: String, tab: NotchTab, verbose: Bool) async throws -> String {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let result: String
            switch provider {
            case .claude: result = try await callClaude(prompt: text, verbose: verbose)
            case .openai: result = try await callOpenAI(prompt: text, verbose: verbose)
            }
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            cacheInsight(trimmed, for: tab, verbose: verbose)
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

    private func callClaude(prompt text: String, verbose: Bool) async throws -> String {
        let key = UserDefaults.standard.string(forKey: Self.claudeKeyUD) ?? ""
        guard !key.isEmpty else { throw InsightError.missingAPIKey }
        let model = UserDefaults.standard.string(forKey: Self.claudeModelUD) ?? "claude-sonnet-4-5"

        var messages: [ClaudeMsg] = [ClaudeMsg(role: "user", content: .text(text))]
        let maxIter = 3

        for _ in 0..<maxIter {
            let body = ClaudeRequest(
                model: model,
                max_tokens: verbose ? 400 : 1024,
                messages: messages,
                tools: MinimaxTools.all
            )
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            req.httpMethod = "POST"
            req.setValue(key,                    forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01",           forHTTPHeaderField: "anthropic-version")
            req.setValue("application/json",     forHTTPHeaderField: "content-type")
            req.httpBody = try? JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw InsightError.invalidResponse(http.statusCode)
            }
            guard let decoded = try? JSONDecoder().decode(ClaudeResponse.self, from: data) else {
                throw InsightError.decodingError
            }

            if decoded.stop_reason != "tool_use" {
                return decoded.content
                    .compactMap { $0.type == "text" ? $0.text : nil }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Echo assistant turn (text + tool_use blocks)
            let assistantBlocks = decoded.content.map { c -> ClaudeMsgBlock in
                if c.type == "tool_use" {
                    return ClaudeMsgBlock(type: "tool_use", tool_use_id: nil, content: nil,
                                         id: c.id, name: c.name, input: c.input)
                } else {
                    return ClaudeMsgBlock(type: "text", tool_use_id: nil, content: c.text,
                                         id: nil, name: nil, input: nil)
                }
            }
            messages.append(ClaudeMsg(role: "assistant", content: .blocks(assistantBlocks)))

            // Execute each tool_use block and collect results
            var resultBlocks: [ClaudeMsgBlock] = []
            for block in decoded.content where block.type == "tool_use" {
                guard let toolId = block.id, let toolName = block.name else { continue }
                currentTool = toolName
                let result = await ToolEngine.shared.execute(name: toolName, input: block.input ?? [:])
                resultBlocks.append(ClaudeMsgBlock(type: "tool_result", tool_use_id: toolId,
                                                   content: result, id: nil, name: nil, input: nil))
            }
            currentTool = nil
            messages.append(ClaudeMsg(role: "user", content: .blocks(resultBlocks)))
        }

        // Max iterations reached — return last text message if any
        return messages.compactMap {
            if case .text(let t) = $0.content { return t }
            return nil
        }.last ?? ""
    }

    // MARK: - OpenAI-compatible (GPT-4, Ollama, LM Studio, etc.)

    private func callOpenAI(prompt text: String, verbose: Bool) async throws -> String {
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
            max_tokens: verbose ? 400 : 120,
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

    private func cachedInsight(for tab: NotchTab, verbose: Bool) -> String? {
        let k = verbose ? tab.verboseCacheKey : tab.cacheKey
        guard let times = cachedTimes(), let ts = times[k],
              Date().timeIntervalSince1970 - ts < cacheTTL,
              let texts = cachedTexts(), let text = texts[k]
        else { return nil }
        return text
    }

    private func cacheInsight(_ text: String, for tab: NotchTab, verbose: Bool) {
        let k = verbose ? tab.verboseCacheKey : tab.cacheKey
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

    // MARK: - Context-aware prompt builders

    private func prompt(for tab: NotchTab, verbose: Bool) -> String {
        switch tab {
        case .home:      return homePrompt(verbose: verbose)
        case .projects:  return projectsPrompt(verbose: verbose)
        case .awareness: return learnPrompt(verbose: verbose)
        case .focus:     return focusPrompt(verbose: verbose)
        }
    }

    private let briefInstruction  = "Give one brief observation. One sentence only."
    private let verboseInstruction = "Give a 2–4 sentence analysis referencing the specific numbers from the data above."

    private func focusPrompt(verbose: Bool) -> String {
        let instruction = verbose ? verboseInstruction : briefInstruction
        let phase = pomodoro.phase
        if phase.isIdle {
            return "User has no active Pomodoro session right now. \(instruction)"
        }
        let minsRemaining = Int(phase.remaining / 60)
        let secsRemaining = Int(phase.remaining) % 60
        let timeStr = "\(minsRemaining)m \(secsRemaining)s"
        let sessions = pomodoro.completedSessions
        let taskStr  = pomodoro.currentTask.map { "Linked to task: \($0.title)." } ?? "No linked task."
        return "Focus session active: \(phase.label) with \(timeStr) remaining. \(sessions) session(s) completed today. \(taskStr) \(instruction)"
    }

    private func projectsPrompt(verbose: Bool) -> String {
        let instruction = verbose ? verboseInstruction : briefInstruction
        guard !projects.projects.isEmpty else {
            return "User has no projects added yet. \(instruction)"
        }
        if let active = projects.active {
            let others = projects.projects.count - 1
            let othersStr = others > 0 ? "\(others) other project(s) tracked." : "Only project."
            return "Active project: \(active.name) (\(active.language)). \(active.sessionsToday) session(s) today, \(active.totalHoursDisplay) total. \(othersStr) \(instruction)"
        }
        let count = projects.projects.count
        let total = projects.projects.reduce(0) { $0 + $1.sessionsToday }
        return "\(count) project(s) tracked, \(total) sessions today, none currently active. \(instruction)"
    }

    private func tasksPrompt(verbose: Bool) -> String {
        let instruction = verbose ? verboseInstruction : briefInstruction
        let pending   = taskStore.pending
        let completed = taskStore.completed.filter {
            Calendar.current.isDateInToday($0.completedAt ?? .distantPast)
        }
        guard !pending.isEmpty || !completed.isEmpty else {
            return "User has no tasks today. \(instruction)"
        }
        let overdue  = pending.filter { $0.urgency == .overdue }.count
        let highPri  = pending.filter { $0.priority == .high }.count
        return "Tasks: \(pending.count) pending (\(overdue) overdue, \(highPri) high-priority), \(completed.count) completed today. \(instruction)"
    }

    private func streakPrompt(verbose: Bool) -> String {
        let instruction = verbose ? verboseInstruction : briefInstruction
        let (streak, today, yesterday) = currentStreakAndToday()
        guard github.contributionsByUser.isEmpty == false else {
            return "User has no GitHub data connected. \(instruction)"
        }
        return "GitHub: \(streak)-day streak. \(today) commit(s) today, \(yesterday) yesterday. \(instruction)"
    }

    private func learnPrompt(verbose: Bool) -> String {
        let instruction = verbose ? verboseInstruction : briefInstruction
        let todayTopics = learning.todayTopics
        guard !todayTopics.isEmpty else {
            return "No learning topics scheduled today. \(instruction)"
        }
        let topicList = todayTopics.prefix(3)
            .map { "\($0.title) (\($0.progress)%)" }
            .joined(separator: ", ")
        return "Learning topics today: \(topicList). \(instruction)"
    }

    private func homePrompt(verbose: Bool) -> String {
        let instruction = verbose ? verboseInstruction : briefInstruction
        let totalSessions = projects.projects.reduce(0) { $0 + $1.sessionsToday }
        let pendingCount  = taskStore.pending.count
        let (streak, _, _) = currentStreakAndToday()
        let learnStr = learning.todayTopics.first.map { ", studying \($0.title) today" } ?? ""
        return "Today so far: \(totalSessions) focus session(s), \(pendingCount) task(s) pending, \(streak)-day GitHub streak\(learnStr). \(instruction)"
    }

    // MARK: - Streak helper (used by streakPrompt + homePrompt)

    private func currentStreakAndToday() -> (streak: Int, todayCount: Int, yesterdayCount: Int) {
        let contributions = github.contributionsByUser
        guard !contributions.isEmpty else { return (0, 0, 0) }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        let cal = Calendar(identifier: .gregorian)

        func totalCommits(on date: Date) -> Int {
            let key = df.string(from: date)
            return contributions.values.reduce(0) { $0 + ($1[key]?.count ?? 0) }
        }

        var streak = 0
        var date = Date()
        while totalCommits(on: date) > 0 {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }

        let today     = totalCommits(on: Date())
        let yesterday = totalCommits(on: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return (streak, today, yesterday)
    }
}

// MARK: - NotchTab cache key

extension NotchTab {
    var cacheKey: String {
        switch self {
        case .home:      return "home"
        case .projects:  return "projects"
        case .awareness: return "awareness"
        case .focus:     return "focus"
        }
    }

    var verboseCacheKey: String { "\(cacheKey)-verbose" }
}
