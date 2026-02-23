import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Library View (資料ライブラリ)
struct DocumentLibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var docService = DocumentService.shared
    @StateObject private var profileManager = ProfileManager.shared

    @State private var showImporter = false
    @State private var showTextInput = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var currentProfileID: UUID? { profileManager.currentProfile?.id }

    var profileDocs: [DocumentItem] {
        docService.documents.filter {
            $0.profileID == currentProfileID || $0.profileID == nil
        }
    }

    var body: some View {
        Group {
            if profileDocs.isEmpty {
                emptyState
            } else {
                documentList
            }
        }
        .navigationTitle("📚 資料ライブラリ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showImporter = true } label: {
                        Label("PDFを追加", systemImage: "doc.fill")
                    }
                    Button { showTextInput = true } label: {
                        Label("テキストを直接入力", systemImage: "text.cursor")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $showTextInput) {
            TextDocumentInputView(profileID: currentProfileID)
        }
        .overlay(alignment: .bottom) {
            if let msg = successMessage {
                Text(msg)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green.cornerRadius(12))
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { successMessage = nil }
                        }
                    }
            }
        }
        .alert("エラー", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("📂")
                .font(.system(size: 70))
            Text("資料ライブラリ")
                .font(.title2.bold())
            Text("PDFやテキストファイルを追加すると、\nAIが内容を覚えて質問に答えてくれます")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                UseCaseCard(emoji: "📋", title: "会社の資料・マニュアル",
                            desc: "「〇〇の手順は？」と聞くとAIが答えます")
                UseCaseCard(emoji: "📖", title: "教科書・参考書",
                            desc: "勉強の質問をするとAIが解説します")
                UseCaseCard(emoji: "🏥", title: "医療・薬の説明書",
                            desc: "「この薬の副作用は？」などを聞けます")
            }
            .padding(.horizontal)

            Button { showImporter = true } label: {
                Label("PDFを追加する", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Document List
    private var documentList: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "info.circle").foregroundColor(.blue)
                    Text("ONにした資料はチャットで自動的に参照されます")
                        .font(.caption).foregroundColor(.secondary)
                }
                .listRowBackground(Color.blue.opacity(0.05))
            }

            Section("追加済み資料 (\(profileDocs.count)件)") {
                ForEach(profileDocs) { doc in
                    DocumentRow(document: doc, onToggle: {
                        docService.toggleDocument(id: doc.id)
                    })
                }
                .onDelete { offsets in
                    offsets.map { profileDocs[$0].id }.forEach {
                        docService.deleteDocument(id: $0)
                    }
                }
            }

            Section {
                Button { showImporter = true } label: {
                    Label("PDFを追加", systemImage: "doc.badge.plus")
                }
                Button { showTextInput = true } label: {
                    Label("テキストを直接入力", systemImage: "text.badge.plus")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Import Handler
    private func handleImport(result: Result<[URL], Error>) {
        isImporting = true
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                let doc = try docService.importPDF(url: url, profileID: currentProfileID)
                withAnimation { successMessage = "「\(doc.filename)」を追加しました 📄" }
            } else {
                let text = try String(contentsOf: url, encoding: .utf8)
                let doc = docService.importText(text, filename: url.lastPathComponent,
                                                 type: .txt, profileID: currentProfileID)
                withAnimation { successMessage = "「\(doc.filename)」を追加しました 📝" }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
    }
}

// MARK: - Document Row
struct DocumentRow: View {
    let document: DocumentItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(document.type.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.filename).font(.body).lineLimit(1)
                HStack(spacing: 8) {
                    Text(document.sizeDescription)
                    Text("·")
                    Text("\(document.chunks.count)チャンク")
                    Text("·")
                    Text(document.importedAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: .init(
                get: { document.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Text Document Input View
struct TextDocumentInputView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var docService = DocumentService.shared

    let profileID: UUID?
    @State private var title = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例：会社の規定、レシピメモなど", text: $title)
                }
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .font(.body)
                }
            }
            .navigationTitle("テキストを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let name = title.isEmpty ? "メモ" : title
                        _ = docService.importText(content, filename: "\(name).txt",
                                                   type: .manual, profileID: profileID)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
        }
    }
}

// MARK: - Use Case Card
struct UseCaseCard: View {
    let emoji: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
