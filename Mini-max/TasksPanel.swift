import SwiftUI

private extension TaskPriority {
    var color: Color {
        switch self {
        case .low:    return Color(white: 0.35)
        case .medium: return Color(red: 0.9, green: 0.7, blue: 0.2)
        case .high:   return Color(red: 0.9, green: 0.3, blue: 0.3)
        }
    }
}

struct TasksPanel: View {
    private let store = TaskStore.shared
    @State private var newTitle = ""
    @State private var isAddingTask = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(store.pending.count) left")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.trailing, 4)
                Button { isAddingTask = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            if isAddingTask {
                HStack(spacing: 6) {
                    TextField("New task...", text: $newTitle)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.1)))
                        .onSubmit { commitAdd() }

                    Button(action: commitAdd) {
                        Image(systemName: "return")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.48, green: 0.70, blue: 0.91))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
            }

            if store.tasks.isEmpty && !isAddingTask {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(store.pending)   { task in TaskRow(task: task) }

                        if !store.completed.isEmpty {
                            Divider()
                                .background(Color(white: 0.15))
                                .padding(.vertical, 4)
                            ForEach(store.completed) { task in TaskRow(task: task) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 18))
                .foregroundStyle(Color(white: 0.28))
            Text("No tasks today")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.28))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitAdd() {
        guard !newTitle.isEmpty else { isAddingTask = false; return }
        store.add(title: newTitle)
        newTitle = ""
        isAddingTask = false
    }
}

private struct TaskRow: View {
    let task: DailyTask
    private let store = TaskStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(task.priority.color)
                .frame(width: 5, height: 5)

            Button { store.toggle(task) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(task.isCompleted
                        ? Color(red: 0.27, green: 0.75, blue: 0.43)
                        : Color(white: 0.3))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 11, weight: task.isCompleted ? .regular : .medium))
                .foregroundStyle(task.isCompleted ? Color(white: 0.35) : .white)
                .strikethrough(task.isCompleted, color: Color(white: 0.35))
                .lineLimit(1)

            Spacer()

            Button { store.delete(task) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(white: 0.25))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(task.isCompleted ? Color.clear : Color(white: 0.06))
        )
    }
}
