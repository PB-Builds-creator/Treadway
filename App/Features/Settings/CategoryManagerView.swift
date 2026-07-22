import SwiftUI
import CairnCore

struct CategoryManagerView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var newName = ""

    var body: some View {
        List {
            Section("Add category") {
                HStack {
                    TextField("Name", text: $newName)
                    Button("Add") {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let category = TaskCategory(name: trimmed, sortIndex: env.categories.count)
                        Task { try? await env.store.upsert(category); await env.refresh() }
                        newName = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Categories") {
                if env.categories.isEmpty {
                    Text("No categories yet.").foregroundStyle(.secondary)
                }
                ForEach(env.categories) { category in
                    Label(category.name, systemImage: category.symbolName)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let id = env.categories[index].id
                        Task { try? await env.store.deleteCategory(id: id); await env.refresh() }
                    }
                }
            }
        }
        .navigationTitle("Categories")
    }
}
