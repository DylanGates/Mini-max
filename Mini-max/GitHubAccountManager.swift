import SwiftUI

// MARK: - Theme

struct AccountTheme {
    let label: String
    // 5 colors: [none, light, mid, heavy, max] — matches github_painter levels 0-4
    let colors: [Color]

    // github_painter green (#262626 / #0D4429 / #016C31 / #26A641 / #39D353)
    static let green = AccountTheme(label: "green", colors: [
        Color(red: 0.149, green: 0.149, blue: 0.149),
        Color(red: 0.051, green: 0.267, blue: 0.161),
        Color(red: 0.004, green: 0.424, blue: 0.192),
        Color(red: 0.149, green: 0.651, blue: 0.255),
        Color(red: 0.224, green: 0.827, blue: 0.325),
    ])

    // Blue  (#262626 / #0D1B4D / #163A8C / #2563EB / #60A5FA)
    static let blue = AccountTheme(label: "blue", colors: [
        Color(red: 0.149, green: 0.149, blue: 0.149),
        Color(red: 0.051, green: 0.106, blue: 0.302),
        Color(red: 0.086, green: 0.227, blue: 0.549),
        Color(red: 0.145, green: 0.388, blue: 0.922),
        Color(red: 0.376, green: 0.647, blue: 0.980),
    ])

    // Orange (#262626 / #431407 / #9A3412 / #EA580C / #FB923C)
    static let orange = AccountTheme(label: "orange", colors: [
        Color(red: 0.149, green: 0.149, blue: 0.149),
        Color(red: 0.263, green: 0.078, blue: 0.027),
        Color(red: 0.604, green: 0.204, blue: 0.071),
        Color(red: 0.918, green: 0.345, blue: 0.047),
        Color(red: 0.984, green: 0.573, blue: 0.235),
    ])

    static let all: [AccountTheme] = [.green, .blue, .orange]
}

// MARK: - Account

struct GitHubAccount: Identifiable {
    let id: String       // SSH Host alias
    let username: String
    let theme: AccountTheme

    var dotColor: Color { theme.colors[3] }
}

// MARK: - Manager

final class GitHubAccountManager {
    static let shared = GitHubAccountManager()

    let accounts: [GitHubAccount]

    private init() {
        accounts = Self.parse()
    }

    // Reads ~/.ssh/config, finds Host entries with HostName github.com,
    // extracts username from the comment directly above each Host block.
    private static func parse() -> [GitHubAccount] {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        guard let raw = try? String(contentsOf: configURL, encoding: .utf8) else { return [] }

        var accounts: [GitHubAccount] = []
        var lastComment: String? = nil
        let lines = raw.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#") {
                lastComment = line
                i += 1
                continue
            }

            if line.lowercased().hasPrefix("host ") && !line.lowercased().hasPrefix("hostname") {
                let hostAlias = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                var hostName  = ""

                // Scan ahead for HostName within this block
                var j = i + 1
                while j < lines.count {
                    let sub = lines[j].trimmingCharacters(in: .whitespaces)
                    if sub.lowercased().hasPrefix("host ") && !sub.lowercased().hasPrefix("hostname") { break }
                    if sub.lowercased().hasPrefix("hostname ") {
                        hostName = String(sub.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    }
                    j += 1
                }

                if hostName.lowercased() == "github.com" {
                    // Extract "(Username)" from comment if present
                    var username = hostAlias
                    if let comment = lastComment,
                       let match = comment.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
                        username = String(comment[match]).dropFirst().dropLast().description
                    }

                    let theme = AccountTheme.all[accounts.count % AccountTheme.all.count]
                    accounts.append(GitHubAccount(id: hostAlias, username: username, theme: theme))
                }

                lastComment = nil
            } else if !line.isEmpty && !line.hasPrefix("#") {
                // Non-blank, non-comment, non-Host line — don't clear comment
                // (indent lines inside a block shouldn't clear the pending comment)
            }

            i += 1
        }

        return accounts
    }
}
