import SwiftUI
import AppKit
import Combine

// MARK: - Display State

@Observable
final class NotchDisplayState {
    var isExpanded = false
}

// MARK: - Active Tab

enum NotchTab { case home, projects, streak, learn, tasks, focus }

// MARK: - Shell

struct NotchShellView: View {
    var state: NotchDisplayState

    var body: some View {
        ZStack {
            NotchShape(bottomCornerRadius: state.isExpanded ? 24 : 10)
                .fill(Color(red: 11/255, green: 11/255, blue: 11/255))

            // Pill eyes (closed state)
            HStack(spacing: 8) {
                Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
            }
            .padding(.bottom, 4)
            .opacity(state.isExpanded ? 0 : 1)

            // Expanded content
            ExpandedNotchContent()
                .opacity(state.isExpanded ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.25), value: state.isExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Expanded Content Root

struct ExpandedNotchContent: View {
    @State private var activeTab: NotchTab = .home

    private var greeting: String {
        let name = NSFullUserName().components(separatedBy: " ").first ?? "there"
        return "Hello, \(name)"
    }

    var body: some View {
        VStack(spacing: 8) {
            NotchHeaderBar(activeTab: $activeTab)

            switch activeTab {
            case .home:
                HStack(alignment: .top, spacing: 12) {
                    MiniMaxHomePanel(greeting: greeting)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    CalendarPanel()
                        .frame(width: 220)
                }
                .frame(maxHeight: .infinity)

            case .projects:
                HStack(alignment: .top, spacing: 12) {
                    ProjectsPanel()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    CalendarPanel()
                        .frame(width: 220)
                }
                .frame(maxHeight: .infinity)

            case .streak:
                StreakPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .learn:
                LearningPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .tasks:
                TasksPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .focus:
                FocusPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.18), value: activeTab)
    }
}

// MARK: - Header Bar

private struct NotchHeaderBar: View {
    @Binding var activeTab: NotchTab
    private let battery = BatteryMonitor.shared

    var body: some View {
        HStack(spacing: 0) {
            // Tab pill
            HStack(spacing: 0) {
                TabPillButton(symbol: "house.fill",    isSelected: activeTab == .home)     { activeTab = .home }
                TabPillButton(symbol: "folder.fill",  isSelected: activeTab == .projects) { activeTab = .projects }
                TabPillButton(symbol: "flame.fill",   isSelected: activeTab == .streak)   { activeTab = .streak }
                TabPillButton(symbol: "book.fill",    isSelected: activeTab == .learn)    { activeTab = .learn }
                TabPillButton(symbol: "checklist",    isSelected: activeTab == .tasks)    { activeTab = .tasks }
                TabPillButton(symbol: "timer",        isSelected: activeTab == .focus)    { activeTab = .focus }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(white: 0.11)))

            Spacer()

            // Right: settings + battery
            HStack(spacing: 6) {
                NotchSettingsButton()
                NotchBatteryView(battery: battery)
            }
        }
    }
}

private struct TabPillButton: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : Color(white: 0.38))
                .frame(width: 26, height: 22)
                .background(
                    Capsule().fill(isSelected ? Color(white: 0.19) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Button (ported from boring.notch BoringHeader)

private struct NotchSettingsButton: View {
    var body: some View {
        Button {
            // TODO: open settings window (Phase 2)
        } label: {
            Capsule()
                .fill(Color(white: 0.13))
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "gear")
                        .foregroundStyle(.white)
                        .imageScale(.small)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Battery View (ported from boring.notch BoringBattery / BatteryView)

private struct NotchBatteryView: View {
    let battery: BatteryMonitor

    // Matches boring.notch: bolt when charging, plug when plugged-in only
    private var powerIcon: String? {
        if battery.isCharging { return "bolt" }
        if battery.isPluggedIn { return "plug" }
        return nil
    }

    // boring.notch batteryColor logic
    private var fillColor: Color {
        if battery.isInLowPowerMode                          { return .yellow }
        if battery.level <= 20 && !battery.isCharging
            && !battery.isPluggedIn                          { return .red    }
        if battery.isCharging || battery.isPluggedIn
            || battery.level == 100                          { return .green  }
        return .white
    }

    private let w: CGFloat = 24  // batteryWidth

    var body: some View {
        HStack(spacing: 4) {
            Text("\(battery.level)%")
                .font(.system(size: 8))
                .foregroundStyle(.white)

            // Battery shell + fill + power icon — same ZStack layout as boring.notch BatteryView
            ZStack(alignment: .leading) {
                Image(systemName: "battery.0")
                    .resizable()
                    .fontWeight(.thin)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: w + 1)

                RoundedRectangle(cornerRadius: 2.5)
                    .fill(fillColor)
                    .frame(
                        width: max(1, (w - 6) * CGFloat(battery.level) / 100),
                        height: w * 0.4 - 4   // ≈ 5.6 px at w=24
                    )
                    .padding(.leading, 2)

                if let icon = powerIcon {
                    ZStack {
                        Image(systemName: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                    }
                    .frame(width: w, height: w)
                }
            }
        }
    }
}

// MARK: - Home Panel (left side)

private struct MiniMaxHomePanel: View {
    let greeting: String

    private let projects  = ProjectStore.shared
    private let tasks     = TaskStore.shared
    private let pomodoro  = PomodoroManager.shared
    private let learning  = LearningStore.shared

    private var activeLabel: String {
        if let p = projects.active {
            let s = p.sessionsToday
            return "\(p.name)  ·  \(s) session\(s == 1 ? "" : "s") today"
        }
        return "no active project"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 5) {
                Image(systemName: "smallcircle.filled.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 66/255, green: 109/255, blue: 157/255))
                Text(activeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.48))
            }

            Spacer(minLength: 0)

            // Eyes
            MiniMaxEyesView()
                .frame(maxWidth: .infinity)
                .frame(height: 36)

            // Thinking dots
            ThinkingBubbleView()

            Text("thinking...")
                .font(.system(size: 8, weight: .light))
                .foregroundStyle(Color(white: 0.22))

            Spacer(minLength: 0)

            // Today summary
            todaySummary
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var todaySummary: some View {
        HStack(spacing: 10) {
            SummaryChip(
                icon: "checkmark.circle",
                value: "\(tasks.completed.count)",
                label: "done",
                color: Color(red: 0.27, green: 0.75, blue: 0.43)
            )
            SummaryChip(
                icon: "timer",
                value: "\(pomodoro.completedSessions)",
                label: "sessions",
                color: Color(red: 0.48, green: 0.70, blue: 0.91)
            )
            SummaryChip(
                icon: "book",
                value: "\(learning.todayTopics.count)",
                label: "topics",
                color: Color(red: 0.75, green: 0.55, blue: 0.90)
            )
        }
    }
}

private struct SummaryChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(Color(white: 0.32))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.07)))
    }
}

// MARK: - Projects Panel

private struct ProjectsPanel: View {
    private let store = ProjectStore.shared
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newLanguage = ""
    @State private var newPath = ""

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)
    private let green  = Color(red: 0.27, green: 0.75, blue: 0.43)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            if showingAdd {
                addForm
                    .padding(.bottom, 8)
            }

            if store.projects.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(store.projects) { project in
                            ProjectRow(project: project)
                            if project.id != store.projects.last?.id {
                                Divider()
                                    .background(Color(white: 0.1))
                                    .padding(.leading, 10)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Projects")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            if !store.projects.isEmpty {
                Text(" · \(store.projects.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.32))
            }

            Spacer()

            // Total time today
            let todaySessions = store.projects.map(\.sessionsToday).reduce(0, +)
            if todaySessions > 0 {
                Text("\(todaySessions) sessions today")
                    .font(.system(size: 9))
                    .foregroundStyle(accent.opacity(0.7))
                    .padding(.trailing, 8)
            }

            Button { showingAdd.toggle() } label: {
                Image(systemName: showingAdd ? "xmark" : "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Add Form

    private var addForm: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(green.opacity(0.5))
                    .frame(width: 2)
                    .cornerRadius(1)

                TextField("Project name", text: $newName)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)

                TextField("lang", text: $newLanguage)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(white: 0.4))
                    .frame(width: 48)
            }

            HStack(spacing: 6) {
                // Folder picker — opens NSOpenPanel
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.prompt = "Select"
                    panel.title = "Choose project folder"
                    if panel.runModal() == .OK {
                        newPath = panel.url?.path ?? ""
                        // Auto-fill name from folder name if still empty
                        if newName.isEmpty, let folderName = panel.url?.lastPathComponent {
                            newName = folderName
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 9))
                        Text(newPath.isEmpty ? "Browse…" : URL(fileURLWithPath: newPath).lastPathComponent)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                    .foregroundStyle(newPath.isEmpty ? Color(white: 0.35) : green.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.08)))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: commitAdd) {
                    Image(systemName: "return")
                        .font(.system(size: 10))
                        .foregroundStyle(newName.isEmpty ? Color(white: 0.25) : accent)
                }
                .buttonStyle(.plain)
                .disabled(newName.isEmpty)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.07)))
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.2))
            Text("No projects yet")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitAdd() {
        guard !newName.isEmpty else { showingAdd = false; return }
        store.add(name: newName, language: newLanguage, path: newPath)
        newName = ""
        newLanguage = ""
        newPath = ""
        showingAdd = false
    }
}

private struct ProjectRow: View {
    let project: Project
    private let store = ProjectStore.shared

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)
    private let green  = Color(red: 0.27, green: 0.75, blue: 0.43)

    var body: some View {
        HStack(spacing: 0) {
            // Active border
            Rectangle()
                .fill(project.isActive ? green : Color(white: 0.12))
                .frame(width: 2)
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    // Name + language badge
                    HStack(spacing: 6) {
                        Text(project.name)
                            .font(.system(size: 11, weight: project.isActive ? .semibold : .regular))
                            .foregroundStyle(project.isActive ? .white : Color(white: 0.58))
                            .lineLimit(1)

                        if !project.language.isEmpty {
                            Text(project.language)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(project.isActive ? accent.opacity(0.8) : Color(white: 0.32))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(
                                    project.isActive ? accent.opacity(0.1) : Color(white: 0.08)
                                ))
                        }
                    }

                    // Path — only shown if set
                    if !project.path.isEmpty {
                        Text(project.path)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Color(white: 0.28))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if project.sessionsToday > 0 {
                        Text("\(project.sessionsToday) today")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(accent.opacity(0.8))
                    }
                    Text(project.totalHoursDisplay)
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.28))
                }

                // Set active / delete
                Menu {
                    Button("Set active") { store.setActive(project) }
                    Button("Delete", role: .destructive) { store.delete(project) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.25))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .padding(.vertical, 7)
            .padding(.leading, 8)
            .padding(.trailing, 4)
        }
    }
}

// MARK: - Streak Panel

private struct StreakPanel: View {
    static let weekCount: Int    = 16
    static let cellSize: CGFloat = 13
    static let cellGap:  CGFloat = 3

    private let accounts = GitHubAccountManager.shared.accounts

    // Per-account mock levels: account index → (day-offset → intensity 0-4)
    // Seeds differ per account so patterns look distinct.
    // Weekends ~30 % chance; weekdays ~70 % chance.
    private var allLevels: [[Int: Int]] {
        accounts.enumerated().map { idx, _ in
            let seed: UInt32 = [2654435761, 1234567891, 3141592653][idx % 3]
            var data: [Int: Int] = [:]
            for i in 0..<(Self.weekCount * 7) {
                let isWeekend = (i % 7 == 0 || i % 7 == 6)
                let h = UInt32(bitPattern: Int32(bitPattern: UInt32(i) &* seed)) & 0xFFFF
                let threshold: UInt32 = isWeekend ? 5000 : 11000
                if h < threshold {
                    data[i] = min(Int(Double(h) / Double(threshold) * 4) + 1, 4)
                }
            }
            return data
        }
    }

    // The Sunday that starts the oldest visible week
    private var gridStartDate: Date {
        let cal = Calendar(identifier: .gregorian)
        let weeksAgo = cal.date(byAdding: .weekOfYear, value: -(Self.weekCount - 1), to: Date())!
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weeksAgo)
        comps.weekday = 1
        return cal.date(from: comps) ?? weeksAgo
    }

    private var currentStreak: Int { 14 }
    private var longestStreak: Int { 31 }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            statsColumn
            heatmapSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Stats

    private var statsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentStreak)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                Text("day streak")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
            }

            Rectangle()
                .fill(Color(white: 0.15))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 5) {
                StatLine(label: "longest", value: "\(longestStreak)d")
            }

            Spacer(minLength: 0)

            // Account legend
            VStack(alignment: .leading, spacing: 4) {
                ForEach(accounts) { acc in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(acc.dotColor)
                            .frame(width: 6, height: 6)
                        Text(acc.username)
                            .font(.system(size: 8))
                            .foregroundStyle(Color(white: 0.5))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(width: 76)
    }

    // MARK: Heatmap

    private var heatmapSection: some View {
        let start   = gridStartDate
        let cal     = Calendar(identifier: .gregorian)
        let today   = Date()
        let snap    = allLevels

        return VStack(alignment: .leading, spacing: Self.cellGap) {
            // Month labels
            HStack(spacing: Self.cellGap) {
                Color.clear.frame(width: 14, height: 9)
                ForEach(0..<Self.weekCount, id: \.self) { w in
                    let date  = cal.date(byAdding: .day, value: w * 7, to: start)!
                    let dayN  = cal.component(.day, from: date)
                    let label = dayN <= 7
                        ? cal.shortMonthSymbols[cal.component(.month, from: date) - 1]
                        : ""
                    Text(label)
                        .font(.system(size: 7))
                        .foregroundStyle(Color(white: 0.3))
                        .frame(width: Self.cellSize, alignment: .leading)
                }
            }

            // Day labels + week columns
            HStack(alignment: .top, spacing: Self.cellGap) {
                // Day-of-week row labels (Sun=0 … Sat=6), show M/W/F
                let rowLabels = ["", "M", "", "W", "", "F", ""]
                VStack(spacing: Self.cellGap) {
                    ForEach(0..<7, id: \.self) { d in
                        Text(rowLabels[d])
                            .font(.system(size: 7))
                            .foregroundStyle(Color(white: 0.28))
                            .frame(width: 10, height: Self.cellSize)
                    }
                }

                // Week columns
                ForEach(0..<Self.weekCount, id: \.self) { w in
                    VStack(spacing: Self.cellGap) {
                        ForEach(0..<7, id: \.self) { d in
                            let offset = w * 7 + d
                            let date   = cal.date(byAdding: .day, value: offset, to: start)!
                            if date > today {
                                // Future — invisible placeholder
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.clear)
                                    .frame(width: Self.cellSize, height: Self.cellSize)
                            } else {
                                // Dominant account: highest level wins; tie → lowest account index
                                let dominant = snap.enumerated().max(by: {
                                    ($0.element[offset] ?? 0) < ($1.element[offset] ?? 0)
                                })
                                let accIdx = dominant?.offset ?? 0
                                let level  = dominant?.element[offset] ?? 0
                                let theme  = accounts.indices.contains(accIdx)
                                    ? accounts[accIdx].theme
                                    : AccountTheme.green
                                MultiHeatCell(level: level, theme: theme)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct MultiHeatCell: View {
    let level: Int
    let theme: AccountTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(theme.colors[min(max(level, 0), 4)])
            .frame(width: StreakPanel.cellSize, height: StreakPanel.cellSize)
    }
}

private struct StatLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.35))
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(white: 0.6))
        }
    }
}

// MARK: - Eyes

struct MiniMaxEyesView: View {
    @State private var blinking = false
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 18) {
            Spacer()
            eyePill
            eyePill
            Spacer()
        }
        .onReceive(timer) { _ in blink() }
    }

    private var eyePill: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(red: 0.88, green: 0.93, blue: 0.97))
            .frame(width: 22, height: blinking ? 2 : 7)
            .shadow(
                color: Color(red: 0.48, green: 0.70, blue: 0.91).opacity(0.5),
                radius: 8
            )
            .animation(.easeInOut(duration: 0.1), value: blinking)
    }

    private func blink() {
        blinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { blinking = false }
    }
}

// MARK: - Thinking Dots (iMessage-style)

struct ThinkingBubbleView: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == phase ? Color(white: 0.78) : Color(white: 0.38))
                    .frame(
                        width: i == phase ? 6 : 5,
                        height: i == phase ? 6 : 5
                    )
                    .animation(.easeInOut(duration: 0.25), value: phase)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Calendar Panel (right side)

struct CalendarPanel: View {
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    private let manager = CalendarManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Month/year + date wheel
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedDate, format: .dateTime.month(.abbreviated))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(selectedDate, format: .dateTime.year())
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.55))
                }
                .frame(width: 40, alignment: .leading)

                DateWheelPicker(selectedDate: $selectedDate)
                    .frame(maxWidth: .infinity, maxHeight: 50)
            }
            .padding(.bottom, 6)

            Rectangle()
                .fill(Color(white: 0.18))
                .frame(height: 0.5)
                .padding(.bottom, 6)

            // Body: access gate or event list
            switch manager.authState {
            case .denied, .restricted:
                CalendarAccessDeniedView()
            case .unknown:
                // Still requesting — show nothing yet
                EmptyView()
            case .authorized:
                EventScrollView(events: manager.events)
            }
        }
        .onChange(of: selectedDate) {
            Task { await manager.selectDate(selectedDate) }
        }
        .onAppear {
            Task { await manager.selectDate(selectedDate) }
        }
    }
}

// MARK: - Date Wheel Picker

struct DateWheelPicker: View {
    @Binding var selectedDate: Date
    @State private var scrollPosition: Int?
    @State private var byClick = false

    private let pastDays   = 14
    private let futureDays = 21
    private let bgColor    = Color(red: 11/255, green: 11/255, blue: 11/255)

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(dateItems) { item in
                        DateCell(
                            label: item.label,
                            day: item.day,
                            isToday: item.isToday,
                            isSelected: item.isSelected
                        ) {
                            selectedDate = item.date
                            byClick = true
                            withAnimation { scrollPosition = item.index }
                        }
                        .id(item.index)
                    }
                }
                .frame(height: 50)
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: scrollPosition) { _, newVal in
                guard !byClick, let idx = newVal,
                      let item = dateItems.first(where: { $0.index == idx })
                else { byClick = false; return }
                selectedDate = item.date
                byClick = false
            }
            .onAppear { scrollToDate(selectedDate, animated: false) }
            .onChange(of: selectedDate) { _, newDate in
                if !byClick { scrollToDate(newDate, animated: true) }
                byClick = false
            }

            // Edge fades
            HStack(spacing: 0) {
                LinearGradient(colors: [bgColor, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 24)
                Spacer()
                LinearGradient(colors: [.clear, bgColor], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 24)
            }
            .allowsHitTesting(false)
        }
    }

    private func scrollToDate(_ date: Date, animated: Bool) {
        let idx = indexForDate(date)
        byClick = true
        if animated { withAnimation { scrollPosition = idx } }
        else { scrollPosition = idx }
    }

    struct DateItem: Identifiable {
        let id = UUID()
        let index: Int
        let date: Date
        let label: String
        let day: String
        let isToday: Bool
        let isSelected: Bool
    }

    private var totalItems: Int { pastDays + futureDays + 1 }

    private var dateItems: [DateItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -pastDays, to: today)!
        let labelFmt = DateFormatter(); labelFmt.dateFormat = "EEE"; labelFmt.locale = .init(identifier: "en_US")
        let dayFmt   = DateFormatter(); dayFmt.dateFormat = "dd"
        return (0..<totalItems).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: start)!
            return DateItem(
                index: offset + 1,
                date: date,
                label: String(labelFmt.string(from: date).prefix(3)),
                day: dayFmt.string(from: date),
                isToday: cal.isDateInToday(date),
                isSelected: cal.isDate(date, inSameDayAs: selectedDate)
            )
        }
    }

    private func indexForDate(_ date: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -pastDays, to: today)!
        let days = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: date)).day ?? 0
        return max(1, min(days + 1, totalItems))
    }
}

private struct DateCell: View {
    let label: String
    let day: String
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(isSelected ? .white : Color(white: 0.5))

                Text(day)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().fill(
                            isSelected
                                ? Color(red: 66/255, green: 109/255, blue: 157/255)
                                : (isToday ? Color(white: 0.25) : .clear)
                        )
                    )
            }
            .frame(width: 28)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - No Access View

private struct CalendarAccessDeniedView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundStyle(Color(white: 0.35))
            Text("Calendar access needed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.4))
            Button("Open Settings") {
                CalendarManager.shared.openSystemSettings()
            }
            .font(.system(size: 10))
            .foregroundStyle(Color(red: 66/255, green: 109/255, blue: 157/255))
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event List

private struct EventScrollView: View {
    let events: [CalEvent]

    private var allDay:  [CalEvent] { events.filter { $0.isAllDay } }
    private var timed:   [CalEvent] { events.filter { !$0.isAllDay } }

    var body: some View {
        if events.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(white: 0.28))
                Text("No events")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.28))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // All-day strip
                        if !allDay.isEmpty {
                            AllDayStrip(events: allDay)
                                .padding(.bottom, 4)
                        }
                        // Timed events
                        ForEach(timed) { event in
                            EventRow(event: event).id(event.id)
                        }
                    }
                }
                .onAppear { scrollToNext(proxy: proxy) }
                .onChange(of: timed) { scrollToNext(proxy: proxy) }
            }
        }
    }

    private func scrollToNext(proxy: ScrollViewProxy) {
        let now = Date()
        let target = timed.first(where: { $0.endDate > now }) ?? timed.last
        guard let t = target else { return }
        DispatchQueue.main.async { proxy.scrollTo(t.id, anchor: .top) }
    }
}

// MARK: - All-Day Strip

private struct AllDayStrip: View {
    let events: [CalEvent]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(events) { event in
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(cgColor: event.calendarColor.cgColor))
                        .frame(width: 5, height: 5)
                    Text(event.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(white: 0.75))
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.14))
                )
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: CalEvent

    private var accentColor: Color {
        Color(cgColor: event.calendarColor.cgColor)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Calendar colour bar — brighter when in progress
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(event.isInProgress ? 1.0 : 0.6))
                .frame(width: 2.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: event.isInProgress ? .semibold : .medium))
                    .foregroundStyle(event.isEnded ? Color(white: 0.45) : .white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.timeRange)
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: event.isEnded ? 0.3 : 0.45))

                    if !event.calendarName.isEmpty {
                        Text("·")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(white: 0.3))
                        Text(event.calendarName)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(white: event.isEnded ? 0.3 : 0.4))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // In-progress pill
            if event.isInProgress {
                Text("now")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(accentColor.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Previews

#Preview("Expanded") {
    let state = NotchDisplayState()
    return NotchShellView(state: state)
        .frame(width: 640, height: 175)
        .background(Color(white: 0.12))
        .onAppear { state.isExpanded = true }
}

#Preview("Pill") {
    let state = NotchDisplayState()
    return NotchShellView(state: state)
        .frame(width: 180, height: 34)
        .background(Color(white: 0.12))
}
