import Foundation
import Observation

// MARK: - Wire types (shared with InsightEngine)

struct MMTool: Encodable {
    let name: String
    let description: String
    let input_schema: MMToolSchema
}

struct MMToolSchema: Encodable {
    let type = "object"
    let properties: [String: MMToolProperty]
    let required: [String]
}

struct MMToolProperty: Encodable {
    let type: String
    let description: String
}

// MARK: - Tool definitions

enum MinimaxTools {
    static let runShell = MMTool(
        name: "run_shell",
        description: "Run a shell command via /bin/zsh -c. Executes in the active project directory if one is set. Returns stdout+stderr combined, truncated to 2000 chars. Use for git commands, file inspection, build status.",
        input_schema: MMToolSchema(
            properties: ["command": MMToolProperty(type: "string", description: "zsh command to run")],
            required: ["command"]
        )
    )

    static let readFile = MMTool(
        name: "read_file",
        description: "Read file contents. Expands ~ in path. Truncated to 4000 chars.",
        input_schema: MMToolSchema(
            properties: ["path": MMToolProperty(type: "string", description: "Absolute or ~-relative file path")],
            required: ["path"]
        )
    )

    static let listDirectory = MMTool(
        name: "list_directory",
        description: "List contents of a directory. Returns sorted newline-separated names.",
        input_schema: MMToolSchema(
            properties: ["path": MMToolProperty(type: "string", description: "Directory path")],
            required: ["path"]
        )
    )

    static let getAppContext = MMTool(
        name: "get_app_context",
        description: "Return current Mini-Max state: active project + path, pending tasks with priorities, pomodoro phase, GitHub streak, today's learning topics.",
        input_schema: MMToolSchema(properties: [:], required: [])
    )

    static let writeFile = MMTool(
        name: "write_file",
        description: "Write text to a file. Expands ~ in path. Allowed only in /tmp, ~/Desktop, or the active project path. Returns 'ok: wrote {path}' on success or '[tool error] ...' on failure.",
        input_schema: MMToolSchema(
            properties: [
                "path": MMToolProperty(type: "string", description: "Absolute or ~-relative file path"),
                "contents": MMToolProperty(type: "string", description: "Text to write to file")
            ],
            required: ["path", "contents"]
        )
    )

    static let fetchURL = MMTool(
        name: "fetch_url",
        description: "Fetch a URL via HTTPS GET. Returns UTF-8 decoded body truncated to 4000 chars.",
        input_schema: MMToolSchema(
            properties: ["url": MMToolProperty(type: "string", description: "HTTPS URL to fetch")],
            required: ["url"]
        )
    )

    static let all: [MMTool] = [runShell, readFile, listDirectory, getAppContext, writeFile, fetchURL]
}

// MARK: - ToolEngine

@Observable
@MainActor
final class ToolEngine {
    static let shared = ToolEngine()

    private let pomodoro  = PomodoroManager.shared
    private let projects  = ProjectStore.shared
    private let taskStore = TaskStore.shared
    private let learning  = LearningStore.shared
    private let github    = GitHubContributionStore.shared

    private init() {}

    func execute(name: String, input: [String: String]) async -> String {
        switch name {
        case "run_shell":       return await runShell(input["command"] ?? "")
        case "read_file":       return readFile(path: input["path"] ?? "")
        case "list_directory":  return listDirectory(path: input["path"] ?? "")
        case "get_app_context": return getAppContext()
        case "write_file":      return await writeFile(path: input["path"] ?? "", contents: input["contents"] ?? "")
        case "fetch_url":       return await fetchURL(urlString: input["url"] ?? "")
        default:                return "[tool error] unknown tool: \(name)"
        }
    }

    // MARK: - run_shell

    private func runShell(_ command: String) async -> String {
        let blocked = ["sudo", "rm -rf", "mkfs", "dd if=", "> /dev/"]
        for term in blocked {
            if command.contains(term) {
                return "[tool error] blocked: \(term)"
            }
        }

        // Capture project path on MainActor before leaving
        let projectPath = projects.active?.path

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]

                if let path = projectPath {
                    let expanded = (path as NSString).expandingTildeInPath
                    let url = URL(fileURLWithPath: expanded)
                    if FileManager.default.fileExists(atPath: expanded) {
                        process.currentDirectoryURL = url
                    }
                }

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    var output = String(data: data, encoding: .utf8) ?? ""
                    if output.count > 2000 {
                        output = String(output.prefix(2000)) + "\n[truncated]"
                    }
                    continuation.resume(returning: output.isEmpty ? "(no output)" : output)
                } catch {
                    continuation.resume(returning: "[tool error] \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - read_file

    private func readFile(path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        guard let contents = try? String(contentsOfFile: expanded, encoding: .utf8) else {
            return "[tool error] cannot read \(path)"
        }
        if contents.count > 4000 {
            return String(contents.prefix(4000)) + "\n[truncated]"
        }
        return contents
    }

    // MARK: - list_directory

    private func listDirectory(path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: expanded) else {
            return "[tool error] cannot list \(path)"
        }
        return items.sorted().joined(separator: "\n")
    }

    // MARK: - write_file

    private func writeFile(path: String, contents: String) async -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let requestedURL = URL(fileURLWithPath: expanded).standardizedFileURL

        // Allowed roots
        var allowedRoots: [String] = ["/tmp", "~/Desktop"].map { ($0 as NSString).expandingTildeInPath }
        if let proj = projects.active?.path, !proj.isEmpty {
            allowedRoots.append((proj as NSString).expandingTildeInPath)
        }

        let isAllowed = allowedRoots.contains { root in
            let rootURL = URL(fileURLWithPath: root).standardizedFileURL
            return requestedURL.path.hasPrefix(rootURL.path)
        }
        guard isAllowed else { return "[tool error] write_file path not allowed: \(path)" }

        let parent = requestedURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try contents.write(to: requestedURL, atomically: true, encoding: .utf8)
            return "ok: wrote \(expanded)"
        } catch {
            return "[tool error] \(error.localizedDescription)"
        }
    }

    // MARK: - get_app_context

    private func getAppContext() -> String {
        var sections: [String] = []

        // Active project
        if let active = projects.active {
            var projectLines = ["Active project: \(active.name) (\(active.language))"]
            if !active.path.isEmpty {
                projectLines.append("Path: \(active.path)")
            }
            sections.append(projectLines.joined(separator: "\n"))
        }

        // Pending tasks (up to 5)
        let pending = taskStore.pending.prefix(5)
        if !pending.isEmpty {
            let taskLines = pending.map { task -> String in
                let overdue = task.urgency == .overdue ? " ⚠️ OVERDUE" : ""
                return "- [\(task.priority.rawValue)] \(task.title)\(overdue)"
            }
            sections.append("Pending tasks:\n" + taskLines.joined(separator: "\n"))
        }

        // Pomodoro
        let phase = pomodoro.phase
        if !phase.isIdle {
            let mins = Int(phase.remaining / 60)
            sections.append("Pomodoro: \(phase.label) — \(mins)m remaining")
        }

        // GitHub streak
        let streak = githubStreak()
        if streak > 0 {
            sections.append("GitHub streak: \(streak) days")
        }

        // Learning topics today
        let topics = learning.todayTopics
        if !topics.isEmpty {
            let topicList = topics.map { $0.title }.joined(separator: ", ")
            sections.append("Learning today: \(topicList)")
        }

        return sections.isEmpty ? "No context available." : sections.joined(separator: "\n\n")
    }

    // MARK: - fetch_url

    private func fetchURL(urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return "[tool error] invalid url: \(urlString)" }
        guard url.scheme?.lowercased() == "https" else { return "[tool error] only https URLs allowed" }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return "[tool error] HTTP \(http.statusCode)"
            }
            guard let s = String(data: data, encoding: .utf8) else { return "[tool error] failed to decode as UTF-8" }
            if s.count > 4000 { return String(s.prefix(4000)) + "\n[truncated]" }
            return s
        } catch {
            return "[tool error] \(error.localizedDescription)"
        }
    }

    private func githubStreak() -> Int {
        let contributions = github.contributionsByUser
        guard !contributions.isEmpty else { return 0 }

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
        return streak
    }
}
