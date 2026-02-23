import Foundation
import SwiftUI

// MARK: - Family Profile
struct FamilyProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconEmoji: String   // アバター絵文字
    var colorHex: String    // テーマカラー
    var role: FamilyRole
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconEmoji: String = "😊",
        colorHex: String = "#4A90D9",
        role: FamilyRole = .adult,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconEmoji = iconEmoji
        self.colorHex = colorHex
        self.role = role
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static func == (lhs: FamilyProfile, rhs: FamilyProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Family Role
enum FamilyRole: String, Codable, CaseIterable {
    case adult = "adult"
    case child = "child"
    case elderly = "elderly"

    var displayName: String {
        switch self {
        case .adult: return "大人"
        case .child: return "子ども"
        case .elderly: return "シニア"
        }
    }

    var defaultEmojis: [String] {
        switch self {
        case .adult: return ["😊", "🙂", "😄", "🧑", "👨", "👩", "🧔", "👱"]
        case .child: return ["👦", "👧", "🧒", "😸", "🐼", "🐶", "🦊", "🐰"]
        case .elderly: return ["👴", "👵", "🧓", "🌸", "🍀", "⭐️", "🌙", "☀️"]
        }
    }

    /// 子ども向けにフィルタリングするか
    var isSafeMode: Bool { self == .child }

    /// 文字を大きくするか
    var useLargeText: Bool { self == .elderly }

    /// システムプロンプトの付加メッセージ
    var systemPromptSuffix: String {
        switch self {
        case .adult: return ""
        case .child: return "\nユーザーは子どもです。やさしく、かわいらしく、短めに答えてください。難しい言葉は使わないでください。"
        case .elderly: return "\nユーザーはシニアの方です。丁寧で分かりやすい言葉を使い、手順は一つひとつ丁寧に説明してください。"
        }
    }
}

// MARK: - Profile Manager
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profiles: [FamilyProfile] = []
    @Published var currentProfileID: UUID?

    private let defaults = UserDefaults.standard
    private let profilesKey = "family_profiles"
    private let currentProfileKey = "current_profile_id"

    var currentProfile: FamilyProfile? {
        guard let id = currentProfileID else { return profiles.first }
        return profiles.first { $0.id == id }
    }

    private init() {
        load()
    }

    func addProfile(_ profile: FamilyProfile) {
        profiles.append(profile)
        if profiles.count == 1 {
            currentProfileID = profile.id
        }
        save()
    }

    func updateProfile(_ profile: FamilyProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            save()
        }
    }

    func deleteProfile(_ profile: FamilyProfile) {
        profiles.removeAll { $0.id == profile.id }
        if currentProfileID == profile.id {
            currentProfileID = profiles.first?.id
        }
        save()
    }

    func switchProfile(to profile: FamilyProfile) {
        currentProfileID = profile.id
        defaults.set(profile.id.uuidString, forKey: currentProfileKey)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
        if let id = currentProfileID {
            defaults.set(id.uuidString, forKey: currentProfileKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: profilesKey),
           let loaded = try? JSONDecoder().decode([FamilyProfile].self, from: data) {
            profiles = loaded
        }
        if let idString = defaults.string(forKey: currentProfileKey),
           let id = UUID(uuidString: idString) {
            currentProfileID = id
        } else {
            currentProfileID = profiles.first?.id
        }
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b)
    }
}
