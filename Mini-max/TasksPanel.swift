import SwiftUI

private extension TaskPriority {
    // Left-border accent instead of a dot — communicates priority via weight, not just color
    var borderColor: Color {
        switch self {
        case .low:    return Color(white: 0.18)
        case .medium: return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.7)
        case .high:   return Color(red: 0.88, green: 0.32, blue: 0.32)
        }
    }

    var label: String {
        switch self {
        case .low: return "low"
        case .medium: return "mid"
        case .high: return "high"
        }
    }
}

struct TasksPanel: View {
    private let store = TaskStore.shared
    @State private var newTitle = ""
    @State private var isAddingTask = false
    @State private var selectedPriority: TaskPriority = .medium

    private let accent = Color(red: 0.48, green: 0.70, blue: 0.91)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            if isAddingTask {
                addRow
                    .padding(.bottom, 8)
            }

            if store.tasks.isEmpty && !isAddingTask {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Pending — drag-to-reorder via List
                        List {
                            ForEach(store.pending) { task in
                                TaskRow(task: task)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparatorTint(Color(white: 0.1))
                                    .listRowInsets(EdgeInsets())
                            }
                            .onMove { store.movePending(fromOffsets: $0, toOffset: $1) }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .frame(height: CGFloat(store.pending.count) * 38)

                        // Completed — recede with opacity + larger gap above
                        if !store.completed.isEmpty {
                            HStack {
                                Text("done")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color(white: 0.22))
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                Spacer()
                            }
                            .padding(.leading, 10)

                            VStack(spacing: 0) {
                                ForEach(store.completed) { task in
                                    TaskRow(task: task)
                                        .opacity(0.45)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Tasks")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            // Pending count badge — motivational signal
            if store.pending.count > 0 {
                Text("\(store.pending.count) left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(store.pending.count > 5
                        ? Color(red: 0.88, green: 0.32, blue: 0.32).opacity(0.8)
                        : Color(white: 0.35))
                    .padding(.trailing, 8)
            }

            Button {
                isAddingTask.toggle()
                if !isAddingTask { newTitle = "" }
            } label: {
                Image(systemName: isAddingTask ? "xmark" : "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add Row

    private var addRow: some View {
        HStack(spacing: 8) {
            // Priority picker inline
            HStack(spacing: 3) {
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    Button { selectedPriority = p } label: {
                        Rectangle()
                            .fill(selectedPriority == p ? p.borderColor : Color(white: 0.15))
                            .frame(width: 3, height: 16)
                            .cornerRadius(1.5)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("New task...", text: $newTitle)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .onSubmit { commitAdd() }

            Button(action: commitAdd) {
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.07)))
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

    private func commitAdd() {
        guard !newTitle.isEmpty else { isAddingTask = false; return }
        store.add(title: newTitle, priority: selectedPriority)
        newTitle = ""
        isAddingTask = false
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: DailyTask
    private let store = TaskStore.shared

    var body: some View {
        HStack(spacing: 0) {
            // Priority border — the dominant hierarchy signal
            Rectangle()
                .fill(task.isCompleted ? Color(white: 0.12) : task.priority.borderColor)
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

                Text(task.title)
                    .font(.system(size: 11, weight: task.isCompleted ? .regular : .medium))
                    .foregroundStyle(task.isCompleted ? Color(white: 0.3) : .white)
                    .strikethrough(task.isCompleted, color: Color(white: 0.28))
                    .lineLimit(1)

                Spacer()

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
    }
}
