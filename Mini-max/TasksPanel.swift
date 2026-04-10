import SwiftUI

// MARK: - Priority helpers

private extension TaskPriority {
    var borderColor: Color {
        switch self {
        case .low:    return Color(white: 0.18)
        case .medium: return Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.7)
        case .high:   return Color(red: 0.88, green: 0.32, blue: 0.32)
        }
    }
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Mid"
        case .high: return "High"
        }
    }
}

// MARK: - Urgency helpers

private extension DailyTask.Urgency {
    var color: Color {
        switch self {
        case .overdue:  return Color(red: 0.88, green: 0.32, blue: 0.32)
        case .dueToday: return Color(red: 1.00, green: 0.62, blue: 0.04)
        case .dueSoon:  return Color(red: 0.48, green: 0.70, blue: 0.91)
        case .later:    return Color(white: 0.35)
        case .none:     return .clear
        }
    }
}

// MARK: - Deadline preset

private enum DeadlinePreset: String, CaseIterable, Identifiable {
    case today    = "Today"
    case tomorrow = "Tomorrow"
    case in3days  = "+3d"
    case in7days  = "+7d"
    case custom   = "Custom"
    case none     = "None"

    var id: String { rawValue }

    func date() -> Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:    return cal.date(bySettingHour: 23, minute: 59, second: 0, of: now)
        case .tomorrow: return cal.date(bySettingHour: 23, minute: 59, second: 0, of: cal.date(byAdding: .day, value: 1, to: now)!)
        case .in3days:  return cal.date(byAdding: .day, value: 3, to: now)
        case .in7days:  return cal.date(byAdding: .day, value: 7, to: now)
        case .custom, .none: return nil
        }
    }
}

// MARK: - Tasks Panel

struct TasksPanel: View {
    private let store = TaskStore.shared
    @State private var isAdding    = false
    @State private var newTitle    = ""
    @State private var newPriority: TaskPriority = .medium
    @State private var newDeadline: DeadlinePreset = .none
    @State private var customDate  = Date()
    @State private var showDatePicker = false
    @State private var newNotes    = ""

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.bottom, 10)

            if isAdding {
                addForm.padding(.bottom, 8)
            }

            if store.tasks.isEmpty && !isAdding {
                emptyState
            } else {
                taskList
            }

            InsightLineView(tab: .tasks, verbose: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.15), value: isAdding)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Tasks")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            if store.pending.count > 0 {
                Text("\(store.pending.count) left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(store.pending.count > 5
                        ? Color(red: 0.88, green: 0.32, blue: 0.32).opacity(0.8)
                        : Color(white: 0.35))
                    .padding(.trailing, 8)
            }

            Button {
                isAdding.toggle()
                if !isAdding { resetForm() }
            } label: {
                Image(systemName: isAdding ? "xmark" : "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add Form

    private var addForm: some View {
        VStack(spacing: 6) {
            // Row 1: priority + title + confirm
            HStack(spacing: 8) {
                priorityPicker(selected: $newPriority)

                TextField("What needs doing…", text: $newTitle)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .onSubmit { commitAdd() }

                Button(action: commitAdd) {
                    Image(systemName: "return")
                        .font(.system(size: 10))
                        .foregroundStyle(newTitle.isEmpty ? Color(white: 0.22) : accent)
                }
                .buttonStyle(.plain)
                .disabled(newTitle.isEmpty)
            }

            Divider().background(Color(white: 0.1))

            // Row 2: deadline presets
            HStack(spacing: 0) {
                Text("Due:")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.30))
                    .padding(.trailing, 6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(DeadlinePreset.allCases) { preset in
                            if preset == .custom {
                                // Custom date picker trigger
                                Button {
                                    newDeadline = .custom
                                    showDatePicker.toggle()
                                } label: {
                                    deadlineChip(
                                        label: newDeadline == .custom
                                            ? customDate.formatted(.dateTime.month(.abbreviated).day())
                                            : "Custom",
                                        selected: newDeadline == .custom
                                    )
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                                    DatePicker("", selection: $customDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .padding(8)
                                        .frame(width: 260)
                                        .background(Color(NSColor.windowBackgroundColor))
                                }
                            } else {
                                Button { newDeadline = preset } label: {
                                    deadlineChip(label: preset.rawValue, selected: newDeadline == preset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Row 3: notes (optional)
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.25))
                TextField("Notes (optional)", text: $newNotes)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(white: 0.1), lineWidth: 0.5))
    }

    @ViewBuilder
    private func deadlineChip(label: String, selected: Bool) -> some View {
        Text(label)
            .font(.system(size: 9, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? accent : Color(white: 0.38))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(selected ? accent.opacity(0.12) : Color(white: 0.08))
                    .overlay(Capsule().stroke(selected ? accent.opacity(0.4) : .clear, lineWidth: 0.5))
            )
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(store.pending) { task in
                TaskRow(task: task)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color(white: 0.08))
                    .listRowInsets(EdgeInsets())
            }
            .onMove { store.movePending(fromOffsets: $0, toOffset: $1) }

            if !store.completed.isEmpty {
                Section {
                    ForEach(store.completed) { task in
                        TaskRow(task: task)
                            .opacity(0.4)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color(white: 0.06))
                            .listRowInsets(EdgeInsets())
                    }
                } header: {
                    Text("done")
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "checklist")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.2))
            Text("Nothing due today")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func commitAdd() {
        guard !newTitle.isEmpty else { isAdding = false; return }
        let dl: Date? = newDeadline == .none ? nil
                      : newDeadline == .custom ? customDate
                      : newDeadline.date()
        store.add(title: newTitle, priority: newPriority, deadline: dl, notes: newNotes)
        resetForm()
    }

    private func resetForm() {
        newTitle    = ""
        newNotes    = ""
        newDeadline = .none
        newPriority = .medium
        isAdding    = false
    }
}

// MARK: - Priority Picker (reusable)

private struct priorityPicker: View {
    @Binding var selected: TaskPriority

    var body: some View {
        HStack(spacing: 3) {
            ForEach(TaskPriority.allCases, id: \.self) { p in
                Button { selected = p } label: {
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(selected == p ? p.borderColor : Color(white: 0.15))
                            .frame(width: 3, height: selected == p ? 18 : 12)
                            .cornerRadius(1.5)
                    }
                    .frame(height: 20, alignment: .bottom)
                }
                .buttonStyle(.plain)
                .help(p.label)
            }
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: DailyTask
    private let store = TaskStore.shared
    @State private var expanded = false
    @State private var editDeadline: Date
    @State private var editNotes: String

    init(task: DailyTask) {
        self.task = task
        _editDeadline = State(initialValue: task.deadline ?? Date())
        _editNotes    = State(initialValue: task.notes)
    }

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 0) {
                // Priority border
                Rectangle()
                    .fill(task.isCompleted ? Color(white: 0.10) : task.priority.borderColor)
                    .frame(width: 2)
                    .padding(.vertical, 1)

                HStack(spacing: 8) {
                    // Checkbox
                    Button { store.toggle(task) } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(task.isCompleted
                                ? Color(red: 0.27, green: 0.75, blue: 0.43).opacity(0.6)
                                : Color(white: 0.28))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.system(size: 11, weight: task.isCompleted ? .regular : .medium))
                            .foregroundStyle(task.isCompleted ? Color(white: 0.3) : .white)
                            .strikethrough(task.isCompleted, color: Color(white: 0.28))
                            .lineLimit(1)

                        // Deadline badge + notes dot
                        HStack(spacing: 5) {
                            if let label = task.deadlineLabel {
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(task.urgency.color)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(task.urgency.color.opacity(0.12)))
                            }
                            if !task.notes.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Color(white: 0.28))
                            }
                        }
                    }

                    Spacer()

                    // Expand / collapse edit strip
                    if !task.isCompleted {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                        } label: {
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(expanded ? accent.opacity(0.7) : Color(white: 0.22))
                        }
                        .buttonStyle(.plain)
                    }

                    Button { store.delete(task) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(white: 0.2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 7)
                .padding(.leading, 8)
                .padding(.trailing, 6)
            }

            // Inline edit strip
            if expanded && !task.isCompleted {
                editStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Edit Strip

    private var editStrip: some View {
        VStack(spacing: 6) {
            // Deadline row
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.30))

                DatePicker("", selection: $editDeadline, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .scaleEffect(0.85, anchor: .leading)
                    .colorScheme(.dark)
                    .onChange(of: editDeadline) { _, newVal in
                        var updated = task
                        updated.deadline = newVal
                        store.update(updated)
                    }

                Spacer()

                // Clear deadline
                if task.deadline != nil {
                    Button {
                        var updated = task
                        updated.deadline = nil
                        store.update(updated)
                    } label: {
                        Text("clear")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(white: 0.28))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Priority row
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.30))

                HStack(spacing: 4) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Button {
                            var updated = task
                            updated.priority = p
                            store.update(updated)
                        } label: {
                            Text(p.label)
                                .font(.system(size: 9, weight: task.priority == p ? .semibold : .regular))
                                .foregroundStyle(task.priority == p ? p.borderColor : Color(white: 0.30))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(
                                    task.priority == p ? p.borderColor.opacity(0.12) : Color.clear
                                ))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }

            // Notes row
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.30))

                TextField("Add notes…", text: $editNotes)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(white: 0.55))
                    .onSubmit {
                        var updated = task
                        updated.notes = editNotes
                        store.update(updated)
                    }
                    .onChange(of: editNotes) { _, val in
                        var updated = task
                        updated.notes = val
                        store.update(updated)
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(white: 0.05))
        .overlay(
            Rectangle()
                .fill(Color(white: 0.1))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}
