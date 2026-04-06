import Foundation
import AppKit
import UniformTypeIdentifiers

enum DataExporter {

    static func export() {
        let payload: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "tasks":      encodeTasks(),
            "learning":   encodeLearning(),
            "projects":   encodeProjects(),
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8)
        else { return }

        let panel = NSSavePanel()
        panel.title           = "Export mini-max data"
        panel.nameFieldStringValue = "minimax-export-\(dateSuffix()).json"
        panel.allowedContentTypes  = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Encoders

    private static func encodeTasks() -> [[String: Any]] {
        TaskStore.shared.tasks.map { t in
            var d: [String: Any] = [
                "id":        t.id.uuidString,
                "title":     t.title,
                "completed": t.isCompleted,
                "priority":  t.priority.rawValue,
                "addedAt":   iso(t.dateAdded),
            ]
            if let c = t.completedAt { d["completedAt"] = iso(c) }
            return d
        }
    }

    private static func encodeLearning() -> [[String: Any]] {
        LearningStore.shared.topics.map { t in [
            "id":           t.id.uuidString,
            "title":        t.title,
            "category":     t.category,
            "notes":        t.notes,
            "progress":     t.progress,
            "scheduledDays": Array(t.scheduledDays).sorted(),
            "addedAt":      iso(t.dateAdded),
        ]}
    }

    private static func encodeProjects() -> [[String: Any]] {
        ProjectStore.shared.projects.map { p in [
            "id":            p.id.uuidString,
            "name":          p.name,
            "language":      p.language,
            "path":          p.path,
            "sessionsToday": p.sessionsToday,
            "totalMinutes":  p.totalMinutes,
            "isActive":      p.isActive,
            "addedAt":       iso(p.dateAdded),
        ]}
    }

    // MARK: - Helpers

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func dateSuffix() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
}
