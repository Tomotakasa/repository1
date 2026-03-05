import SwiftUI

// MARK: - Memory View (AIの記憶管理)
struct MemoryView: View {
    @StateObject private var memoryService = MemoryService.shared
    @StateObject private var profileManager = ProfileManager.shared
    @State private var showAddMemory = false
    @State private var selectedCategory: MemoryCategory? = nil

    var currentProfileID: UUID? { profileManager.currentProfile?.id }

    var filteredMemories: [MemoryItem] {
        memoryService.memories.filter { item in
            (item.profileID == currentProfileID || item.profileID == nil) &&
            (selectedCategory == nil || item.category == selectedCategory)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // カテゴリフィルター
            categoryFilter

            // 記憶リスト
            if filteredMemories.isEmpty {
                emptyState
            } else {
                memoryList
            }
        }
        .navigationTitle("🧠 AIの記憶")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddMemory = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMemory) {
            AddMemoryView(profileID: currentProfileID)
        }
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "すべて", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(MemoryCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        label: "\(cat.emoji) \(cat.displayName)",
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🧠")
                .font(.system(size: 60))
            Text("まだ記憶がありません")
                .font(.title3.bold())
            Text("AIとの会話を続けると、自動的に\nあなたのことを覚えていきます。\n手動で追加することもできます。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button { showAddMemory = true } label: {
                Label("記憶を手動で追加", systemImage: "plus.circle")
                    .foregroundColor(.accentColor)
            }
            Spacer()
        }
    }

    // MARK: - Memory List
    private var memoryList: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "info.circle").foregroundColor(.blue)
                    Text("ONにした記憶はAIとの会話で自動的に使われます")
                        .font(.caption).foregroundColor(.secondary)
                }
                .listRowBackground(Color.blue.opacity(0.05))
            }

            ForEach(MemoryCategory.allCases, id: \.self) { category in
                let items = filteredMemories.filter { $0.category == category }
                if !items.isEmpty {
                    Section("\(category.emoji) \(category.displayName)") {
                        ForEach(items) { item in
                            MemoryRow(item: item, onToggle: {
                                memoryService.toggleMemory(id: item.id)
                            })
                        }
                        .onDelete { offsets in
                            offsets.map { items[$0].id }.forEach {
                                memoryService.deleteMemory(id: $0)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Memory Row
struct MemoryRow: View {
    let item: MemoryItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.content)
                    .font(.body)
                    .foregroundColor(item.isEnabled ? .primary : .secondary)
                    .lineLimit(2)
                Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundColor(.tertiary)
            }
            Spacer()
            Toggle("", isOn: .init(
                get: { item.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Add Memory View
struct AddMemoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var memoryService = MemoryService.shared

    let profileID: UUID?
    @State private var content = ""
    @State private var category: MemoryCategory = .general

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("例：猫が好き、毎朝ランニングをする...", text: $content, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $category) {
                        ForEach(MemoryCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: "tag").tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("記憶を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        memoryService.addMemory(MemoryItem(
                            content: content, category: category, profileID: profileID))
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
        }
    }
}
