import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @State private var selectedTab = "General"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: "General") {
                    Label("General", systemImage: "gear")
                }
                NavigationLink(value: "Appearance") {
                    Label("Appearance", systemImage: "paintbrush")
                }
                NavigationLink(value: "Notifications") {
                    Label("Notifications", systemImage: "bell")
                }
                NavigationLink(value: "GitHub") {
                    Label("GitHub", systemImage: "person.2")
                }
                NavigationLink(value: "Focus") {
                    Label("Focus", systemImage: "timer")
                }
                NavigationLink(value: "AI") {
                    Label("AI", systemImage: "sparkles")
                }
                NavigationLink(value: "Data") {
                    Label("Data", systemImage: "cylinder")
                }
                NavigationLink(value: "About") {
                    Label("About", systemImage: "info.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case "General":       GeneralSettingsPane()
                case "Appearance":    AppearanceSettingsPane()
                case "Notifications": NotificationsSettingsPane()
                case "GitHub":        GitHubSettingsPane()
                case "Focus":         FocusSettingsPane()
                case "AI":            AISettingsPane()
                case "Data":          DataSettingsPane()
                case "About":         AboutSettingsPane()
                default:              GeneralSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .frame(width: 700)
    }
}

// MARK: - Shared pane header

private struct PaneHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 22, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "General")
            Form {
                Section("System") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled { try SMAppService.mainApp.register() }
                                else       { try SMAppService.mainApp.unregister() }
                            } catch {
                                print("[Settings] launch-at-login: \(error)")
                            }
                        }
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - GitHub

private struct GitHubSettingsPane: View {
    private let accounts = GitHubAccountManager.shared.accounts
    private let store    = GitHubContributionStore.shared
    @State private var drafts: [String: String] = [:]
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "GitHub")
            Form {
                Section("Personal Access Tokens") {
                    if accounts.isEmpty {
                        Text("No GitHub accounts found in ~/.ssh/config")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(accounts) { account in
                            LabeledContent(account.username) {
                                SecureField("ghp_…", text: Binding(
                                    get: { drafts[account.username] ?? store.token(for: account.username) },
                                    set: { drafts[account.username] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)
                                .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        if saved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.callout)
                        }
                        Spacer()
                        Button("Save & Fetch") {
                            for (username, token) in drafts {
                                store.setToken(token, for: username)
                            }
                            drafts = [:]
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                            Task { await store.fetchAll() }
                        }
                        .disabled(accounts.isEmpty || drafts.isEmpty)
                    }
                } footer: {
                    Text("Create a PAT with **read:user** and **repo** scopes at github.com → Settings → Developer settings → Personal access tokens.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Focus

private struct FocusSettingsPane: View {
    private let mgr = PomodoroManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Focus")
            Form {
                Section("Durations") {
                    Stepper("Focus: \(mgr.focusMinutes) min", value: Binding(
                        get: { mgr.focusMinutes },
                        set: { mgr.focusMinutes = $0 }
                    ), in: 5...120, step: 5)

                    Stepper("Short Break: \(mgr.shortBreakMinutes) min", value: Binding(
                        get: { mgr.shortBreakMinutes },
                        set: { mgr.shortBreakMinutes = $0 }
                    ), in: 1...30, step: 1)

                    Stepper("Long Break: \(mgr.longBreakMinutes) min", value: Binding(
                        get: { mgr.longBreakMinutes },
                        set: { mgr.longBreakMinutes = $0 }
                    ), in: 5...60, step: 5)

                    Stepper("Sessions Before Long Break: \(mgr.sessionsBeforeLong)", value: Binding(
                        get: { mgr.sessionsBeforeLong },
                        set: { mgr.sessionsBeforeLong = $0 }
                    ), in: 2...8, step: 1)
                }

                Section("Progress") {
                    LabeledContent("Completed Sessions Today") {
                        HStack {
                            Text("\(mgr.completedSessions)")
                                .foregroundStyle(.secondary)
                            Button("Reset") {
                                mgr.completedSessions = 0
                                UserDefaults.standard.set(0, forKey: "minimax.pomodoro.sessions")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Data

private struct DataSettingsPane: View {
    @State private var confirmClear: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Data")
            Form {
                Section("Export") {
                    Button("Export All Data as JSON…") {
                        DataExporter.export()
                    }
                }

                Section("Clear Data") {
                    clearRow("Tasks", key: "tasks") {
                        TaskStore.shared.tasks.removeAll()
                        UserDefaults.standard.removeObject(forKey: "minimax.tasks")
                    }
                    clearRow("Learning Topics", key: "learning") {
                        LearningStore.shared.topics.removeAll()
                        UserDefaults.standard.removeObject(forKey: "minimax.learning.topics")
                    }
                    clearRow("GitHub Cache", key: "github") {
                        UserDefaults.standard.removeObject(forKey: "minimax.github.contributionCache")
                        UserDefaults.standard.removeObject(forKey: "minimax.github.contributionCacheTime")
                        GitHubContributionStore.shared.contributionsByUser = [:]
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder
    private func clearRow(_ label: String, key: String, action: @escaping () -> Void) -> some View {
        LabeledContent(label) {
            if confirmClear == key {
                HStack(spacing: 8) {
                    Button("Cancel") { confirmClear = nil }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Clear", role: .destructive) { action(); confirmClear = nil }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                Button("Clear…") { confirmClear = key }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - AI

private struct AIPreset {
    let name    : String
    let provider: AIProvider
    let baseURL : String   // empty = not applicable (Claude)
    let model   : String
    let keyHint : String   // placeholder for the API key field
}

private let aiPresets: [AIPreset] = [
    // Claude
    AIPreset(name: "Claude (Anthropic)",    provider: .claude,  baseURL: "",                                                       model: "claude-sonnet-4-6",          keyHint: "sk-ant-…"),
    // OpenAI
    AIPreset(name: "GPT-4o (OpenAI)",       provider: .openai,  baseURL: "https://api.openai.com",                                 model: "gpt-4o",                     keyHint: "sk-…"),
    AIPreset(name: "o3 (OpenAI)",           provider: .openai,  baseURL: "https://api.openai.com",                                 model: "o3",                         keyHint: "sk-…"),
    // Moonshot / Kimi
    AIPreset(name: "Kimi K2 (Moonshot)",    provider: .openai,  baseURL: "https://api.moonshot.cn/v1",                             model: "kimi-k2",                    keyHint: "sk-…"),
    AIPreset(name: "Kimi k1.5 (Moonshot)",  provider: .openai,  baseURL: "https://api.moonshot.cn/v1",                             model: "moonshot-v1-8k",             keyHint: "sk-…"),
    // DeepSeek
    AIPreset(name: "DeepSeek Chat",         provider: .openai,  baseURL: "https://api.deepseek.com",                               model: "deepseek-chat",              keyHint: "sk-…"),
    AIPreset(name: "DeepSeek R1",           provider: .openai,  baseURL: "https://api.deepseek.com",                               model: "deepseek-reasoner",          keyHint: "sk-…"),
    // Groq
    AIPreset(name: "Llama 3.3 70B (Groq)",  provider: .openai,  baseURL: "https://api.groq.com/openai/v1",                         model: "llama-3.3-70b-versatile",    keyHint: "gsk_…"),
    AIPreset(name: "Mixtral (Groq)",        provider: .openai,  baseURL: "https://api.groq.com/openai/v1",                         model: "mixtral-8x7b-32768",         keyHint: "gsk_…"),
    // Gemini
    AIPreset(name: "Gemini 2.0 Flash",      provider: .openai,  baseURL: "https://generativelanguage.googleapis.com/v1beta/openai", model: "gemini-2.0-flash",           keyHint: "AIza…"),
    AIPreset(name: "Gemini 2.5 Pro",        provider: .openai,  baseURL: "https://generativelanguage.googleapis.com/v1beta/openai", model: "gemini-2.5-pro-preview-06-05", keyHint: "AIza…"),
    // Mistral
    AIPreset(name: "Mistral Large",         provider: .openai,  baseURL: "https://api.mistral.ai/v1",                              model: "mistral-large-latest",       keyHint: "…"),
    // Local
    AIPreset(name: "Ollama (local)",        provider: .openai,  baseURL: "http://localhost:11434",                                 model: "llama3.2",                   keyHint: "(leave blank)"),
    AIPreset(name: "LM Studio (local)",     provider: .openai,  baseURL: "http://localhost:1234",                                  model: "local-model",                keyHint: "(leave blank)"),
    // Custom
    AIPreset(name: "Custom…",              provider: .openai,  baseURL: "",                                                       model: "",                           keyHint: "…"),
]

private struct AISettingsPane: View {
    private let engine = InsightEngine.shared

    @AppStorage(InsightEngine.providerUD)    private var providerRaw  = AIProvider.claude.rawValue
    @AppStorage(InsightEngine.claudeKeyUD)   private var claudeKey    = ""
    @AppStorage(InsightEngine.claudeModelUD) private var claudeModel  = "claude-sonnet-4-6"
    @AppStorage(InsightEngine.openAIKeyUD)   private var openAIKey    = ""
    @AppStorage(InsightEngine.openAIBaseUD)  private var openAIBase   = "https://api.openai.com"
    @AppStorage(InsightEngine.openAIModelUD) private var openAIModel  = "gpt-4o"

    @State private var selectedPreset = aiPresets[0].name
    @State private var testResult: String?
    @State private var testing    = false

    private var provider: AIProvider {
        AIProvider(rawValue: providerRaw) ?? .claude
    }

    private var currentPreset: AIPreset? {
        aiPresets.first { $0.name == selectedPreset }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "AI")
            Form {
                Section("Model") {
                    Picker("Preset", selection: $selectedPreset) {
                        ForEach(aiPresets, id: \.name) { preset in
                            Text(preset.name).tag(preset.name)
                        }
                    }
                    .onChange(of: selectedPreset) { _, name in
                        guard let p = aiPresets.first(where: { $0.name == name }) else { return }
                        providerRaw = p.provider.rawValue
                        if p.provider == .openai && !p.baseURL.isEmpty { openAIBase = p.baseURL }
                        if !p.model.isEmpty {
                            if p.provider == .claude { claudeModel = p.model }
                            else                     { openAIModel = p.model }
                        }
                    }
                }

                if provider == .claude {
                    Section("Claude") {
                        LabeledContent("API Key") {
                            SecureField(currentPreset?.keyHint ?? "sk-ant-…", text: $claudeKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)
                                .font(.system(.body, design: .monospaced))
                        }
                        LabeledContent("Model") {
                            TextField("claude-sonnet-4-6", text: $claudeModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .font(.system(.body, design: .monospaced))
                        }
                    } footer: {
                        Text("Create an API key at console.anthropic.com.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Connection") {
                        LabeledContent("API Key") {
                            SecureField(currentPreset?.keyHint ?? "sk-…", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)
                                .font(.system(.body, design: .monospaced))
                        }
                        LabeledContent("Base URL") {
                            TextField("https://api.openai.com", text: $openAIBase)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)
                                .font(.system(.body, design: .monospaced))
                        }
                        LabeledContent("Model") {
                            TextField("gpt-4o", text: $openAIModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .font(.system(.body, design: .monospaced))
                        }
                    } footer: {
                        Text("Fields are pre-filled by the preset and can be overridden. For local models leave the API key blank.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Button(testing ? "Testing…" : "Test Connection") {
                            testing = true
                            testResult = nil
                            Task {
                                do {
                                    let result = try await engine.regenerate(for: .awareness)
                                    await MainActor.run {
                                        testResult = "✓ \(result.prefix(80))"
                                        testing = false
                                    }
                                } catch {
                                    await MainActor.run {
                                        testResult = "✗ \(error.localizedDescription)"
                                        testing = false
                                    }
                                }
                            }
                        }
                        .disabled(testing)
                        .buttonStyle(.bordered)

                        if let result = testResult {
                            Text(result)
                                .font(.system(size: 11))
                                .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
                                .lineLimit(2)
                        }
                    }
                } footer: {
                    Text("Sends one test request using the Home tab context.")
                        .foregroundStyle(.secondary)
                }

                Section("Cache") {
                    LabeledContent("Insight Cache") {
                        Button("Clear Cache") {
                            UserDefaults.standard.removeObject(forKey: "minimax.insight.cache")
                            UserDefaults.standard.removeObject(forKey: "minimax.insight.cacheTime")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } footer: {
                    Text("Insights are cached per tab for 5 minutes. Clear to force a fresh fetch.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - About

private struct AboutSettingsPane: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "About")
            Form {
                Section {
                    LabeledContent("Version", value: "\(version) (\(build))")
                    LabeledContent("Developer", value: "Mini-Max")
                }

                Section {
                    Button("View on GitHub") {
                        NSWorkspace.shared.open(URL(string: "https://github.com")!)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettingsPane: View {
    @AppStorage("minimax.appearance.expandAnimation") private var expandAnimation = "spring"
    @AppStorage("minimax.appearance.showBatteryPercent") private var showBatteryPercent = true
    @AppStorage("minimax.appearance.collapsedEyeOpacity") private var eyeOpacity = 0.72

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Appearance")
            Form {
                Section("Notch") {
                    Picker("Expand Animation", selection: $expandAnimation) {
                        Text("Spring").tag("spring")
                        Text("Ease Out").tag("easeOut")
                        Text("Linear").tag("linear")
                    }
                    .pickerStyle(.menu)

                    LabeledContent("Collapsed Eye Opacity") {
                        HStack {
                            Slider(value: $eyeOpacity, in: 0.2...1.0, step: 0.05)
                                .frame(width: 140)
                            Text(String(format: "%.0f%%", eyeOpacity * 100))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                Section("Status Bar") {
                    Toggle("Show Battery Percentage", isOn: $showBatteryPercent)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Notifications

private struct NotificationsSettingsPane: View {
    @AppStorage("minimax.notif.pomodoroPhase") private var pomodoroPhase = true
    @AppStorage("minimax.notif.taskReminders") private var taskReminders = false
    @AppStorage("minimax.notif.calendarAlerts") private var calendarAlerts = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(title: "Notifications")
            Form {
                Section("Pomodoro") {
                    Toggle("Phase change alerts (focus → break, break → focus)", isOn: $pomodoroPhase)
                }

                Section("Tasks") {
                    Toggle("Daily task reminders", isOn: $taskReminders)
                        .onChange(of: taskReminders) { _, enabled in
                            if enabled { requestNotificationPermission() }
                        }
                }

                Section("Calendar") {
                    Toggle("Upcoming event alerts", isOn: $calendarAlerts)
                }

                Section {
                    Button("Open Notification Settings…") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                        )
                    }
                } footer: {
                    Text("Mini-Max must be granted notification permission in System Settings.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

#Preview {
    SettingsView()
}
