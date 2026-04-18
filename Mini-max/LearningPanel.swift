import SwiftUI

// Calendar weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
private let dayLabels: [(Int, String)] = [
    (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")
]

struct LearningPanel: View {
    private let store = LearningStore.shared
    @State private var showingAdd = false
    @State private var newTitle = ""
    @State private var newCategory = ""
    @State private var newDays: Set<Int> = []
    @State private var showTodayOnly = false
    @Binding var eyesTrigger: UUID

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)

    private var displayTopics: [LearningTopic] {
        let base = showTodayOnly ? store.todayTopics : store.activeTopics
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            if showingAdd {
                addRow
                    .padding(.bottom, 8)
            }

            if displayTopics.isEmpty && store.completedTopics.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(displayTopics) { topic in
                        TopicRow(topic: topic)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color(white: 0.08))
                            .listRowInsets(EdgeInsets())
                    }
                    .onMove { store.moveActive(fromOffsets: $0, toOffset: $1) }

                    if !store.completedTopics.isEmpty && !showTodayOnly {
                        Section {
                            ForEach(store.completedTopics) { topic in
                                TopicRow(topic: topic)
                                    .opacity(0.45)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparatorTint(Color(white: 0.06))
                                    .listRowInsets(EdgeInsets())
                            }
                        } header: {
                            Text("completed")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color(white: 0.22))
                                .textCase(nil)
                                .padding(.leading, 10)
                                .padding(.vertical, 4)
                        }
                        .listSectionSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            InsightLineView(tab: .awareness, verbose: true, refreshTrigger: eyesTrigger)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Learning")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            if !store.topics.isEmpty {
                Text(" · \(store.topics.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.32))
            }

            Spacer()

            // Today filter toggle
            if !store.topics.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showTodayOnly.toggle() }
                } label: {
                    Text("today")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(showTodayOnly ? accent : Color(white: 0.32))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(showTodayOnly ? accent.opacity(0.12) : Color.clear)
                                .overlay(Capsule().stroke(showTodayOnly ? accent.opacity(0.3) : Color(white: 0.18), lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }

            // Avg progress
            if !store.topics.isEmpty {
                let avg = store.topics.map(\.progress).reduce(0, +) / store.topics.count
                Text("\(avg)%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(avg > 60 ? accent : Color(white: 0.35))
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

    // MARK: - Add Row

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(accent.opacity(0.4))
                    .frame(width: 2)
                    .cornerRadius(1)

                TextField("What are you learning?", text: $newTitle)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)

                TextField("tag", text: $newCategory)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(white: 0.4))
                    .frame(width: 44)

                Button(action: commitAdd) {
                    Image(systemName: "return")
                        .font(.system(size: 10))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            // Day picker
            HStack(spacing: 4) {
                Text("schedule:")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.3))

                ForEach(dayLabels, id: \.0) { day, label in
                    let selected = newDays.contains(day)
                    Button {
                        if selected { newDays.remove(day) } else { newDays.insert(day) }
                    } label: {
                        Text(label)
                            .font(.system(size: 9, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? accent : Color(white: 0.28))
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(selected ? accent.opacity(0.15) : Color.clear))
                    }
                    .buttonStyle(.plain)
                }

                if !newDays.isEmpty {
                    Text("(any day if none)")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(white: 0.2))
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.07)))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: showTodayOnly ? "calendar.badge.clock" : "book.closed")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.2))
            Text(showTodayOnly ? "Nothing scheduled today" : "Nothing tracked yet")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitAdd() {
        guard !newTitle.isEmpty else { showingAdd = false; return }
        store.add(title: newTitle, category: newCategory, scheduledDays: newDays)
        newTitle = ""
        newCategory = ""
        newDays = []
        showingAdd = false
    }
}

// MARK: - Topic Row

private struct TopicRow: View {
    let topic: LearningTopic
    private let store = LearningStore.shared
    @State private var showDayPicker = false
    @State private var showNotes = false
    @State private var notesBuffer = ""

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }
    private var isScheduledToday: Bool {
        topic.scheduledDays.isEmpty || topic.scheduledDays.contains(todayWeekday)
    }

    private var borderAccent: Color {
        if !isScheduledToday { return Color(white: 0.14) }
        switch topic.progress {
        case 0..<25:  return Color(white: 0.2)
        case 25..<75: return accent.opacity(0.5)
        default:      return accent
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(borderAccent)
                .frame(width: 2)
                .cornerRadius(1)

            VStack(alignment: .leading, spacing: 4) {
                // Title row
                HStack(spacing: 6) {
                    Text(topic.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isScheduledToday ? .white : Color(white: 0.45))
                        .lineLimit(1)

                    if !topic.category.isEmpty {
                        Text(topic.category)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(accent.opacity(0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(accent.opacity(0.1)))
                    }

                    Spacer()

                    // Day schedule dots — tap to edit
                    Button { withAnimation { showDayPicker.toggle() } } label: {
                        dayScheduleView
                    }
                    .buttonStyle(.plain)

                    // Notes toggle
                    Button {
                        if !showNotes { notesBuffer = topic.notes }
                        withAnimation(.easeInOut(duration: 0.15)) { showNotes.toggle() }
                        if !showNotes { store.updateNotes(topic, notes: notesBuffer) }
                    } label: {
                        Image(systemName: showNotes ? "note.text.badge.plus" : "note.text")
                            .font(.system(size: 8))
                            .foregroundStyle(topic.notes.isEmpty ? Color(white: 0.22) : accent.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    Button { store.delete(topic) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(white: 0.22))
                    }
                    .buttonStyle(.plain)
                }

                // Day picker (inline, expandable)
                if showDayPicker {
                    HStack(spacing: 4) {
                        ForEach(dayLabels, id: \.0) { day, label in
                            let selected = topic.scheduledDays.contains(day)
                            Button {
                                var days = topic.scheduledDays
                                if selected { days.remove(day) } else { days.insert(day) }
                                store.updateDays(topic, days: days)
                            } label: {
                                Text(label)
                                    .font(.system(size: 9, weight: selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? accent : Color(white: 0.28))
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(selected ? accent.opacity(0.15) : Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Progress track
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.1))
                        Capsule().fill(borderAccent)
                            .scaleEffect(x: CGFloat(topic.progress) / 100, y: 1, anchor: .leading)
                    }
                    .frame(height: 4)

                    Text("\(topic.progress)%")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(topic.progress > 0 ? borderAccent : Color(white: 0.22))
                        .frame(width: 28, alignment: .trailing)
                }

                // Milestone stepper
                HStack(spacing: 0) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { val in
                        Button { store.updateProgress(topic, progress: val) } label: {
                            Text(val == 0 ? "·" : "\(val)")
                                .font(.system(size: 8, weight: topic.progress == val ? .semibold : .regular))
                                .foregroundStyle(topic.progress == val ? accent : Color(white: 0.22))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Inline notes editor
                if showNotes {
                    TextEditor(text: $notesBuffer)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.65))
                        .scrollContentBackground(.hidden)
                        .background(Color(white: 0.05))
                        .frame(minHeight: 44, maxHeight: 80)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.2), lineWidth: 0.5))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onChange(of: notesBuffer) { _, new in
                            store.updateNotes(topic, notes: new)
                        }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .opacity(isScheduledToday ? 1 : 0.55)
    }

    // Compact day badges — shows which days are scheduled
    @ViewBuilder
    private var dayScheduleView: some View {
        if topic.scheduledDays.isEmpty {
            Text("every day")
                .font(.system(size: 8))
                .foregroundStyle(Color(white: 0.25))
        } else {
            HStack(spacing: 2) {
                ForEach(dayLabels, id: \.0) { day, label in
                    let active = topic.scheduledDays.contains(day)
                    let isToday = day == todayWeekday
                    Text(label)
                        .font(.system(size: 7, weight: active ? .semibold : .regular))
                        .foregroundStyle(
                            active && isToday ? accent :
                            active ? Color(white: 0.5) :
                            Color(white: 0.18)
                        )
                }
            }
        }
    }
}
