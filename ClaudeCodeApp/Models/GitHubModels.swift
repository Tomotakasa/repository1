import Foundation

// MARK: - GitHub User
struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String
    let email: String?
    let bio: String?
    let publicRepos: Int
    let followers: Int

    enum CodingKeys: String, CodingKey {
        case id, login, name, email, bio, followers
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
    }
}

// MARK: - GitHub Repository
struct GitHubRepository: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let isPrivate: Bool
    let htmlUrl: String
    let defaultBranch: String
    let language: String?
    let stargazersCount: Int
    let updatedAt: Date?
    let owner: RepositoryOwner

    struct RepositoryOwner: Codable, Hashable {
        let login: String
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case login
            case avatarUrl = "avatar_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }

    static func == (lhs: GitHubRepository, rhs: GitHubRepository) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - GitHub Content (ファイル/ディレクトリ)
struct GitHubContent: Codable, Identifiable, Hashable {
    var id: String { sha + path }
    let name: String
    let path: String
    let sha: String
    let size: Int
    let type: ContentType
    let downloadUrl: String?
    let htmlUrl: String?

    enum ContentType: String, Codable {
        case file = "file"
        case directory = "dir"
        case symlink = "symlink"
        case submodule = "submodule"
    }

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, type
        case downloadUrl = "download_url"
        case htmlUrl = "html_url"
    }

    var isDirectory: Bool { type == .directory }

    var fileExtension: String? {
        guard type == .file else { return nil }
        return (name as NSString).pathExtension.lowercased()
    }

    var languageFromExtension: String {
        switch fileExtension {
        case "swift": return "swift"
        case "kt", "kts": return "kotlin"
        case "py": return "python"
        case "js", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "jsx": return "jsx"
        case "java": return "java"
        case "go": return "go"
        case "rs": return "rust"
        case "rb": return "ruby"
        case "php": return "php"
        case "cs": return "csharp"
        case "cpp", "cc", "cxx": return "cpp"
        case "c", "h": return "c"
        case "html", "htm": return "html"
        case "css", "scss", "sass": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "xml": return "xml"
        case "md", "mdx": return "markdown"
        case "sh", "bash", "zsh": return "bash"
        case "sql": return "sql"
        case "dockerfile", "": return name.lowercased() == "dockerfile" ? "dockerfile" : "plaintext"
        default: return "plaintext"
        }
    }

    var systemIcon: String {
        if isDirectory { return "folder.fill" }
        switch fileExtension {
        case "swift": return "swift"
        case "kt", "kts": return "k.square.fill"
        case "py": return "p.square.fill"
        case "js", "ts", "jsx", "tsx": return "j.square.fill"
        case "md", "mdx": return "doc.text.fill"
        case "json", "yaml", "yml", "xml": return "doc.badge.gearshape.fill"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }

    static func == (lhs: GitHubContent, rhs: GitHubContent) -> Bool {
        lhs.sha == rhs.sha && lhs.path == rhs.path
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sha)
        hasher.combine(path)
    }
}

// MARK: - GitHub File Content (ファイル内容付き)
struct GitHubFileContent: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let content: String  // Base64エンコード済み
    let encoding: String
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, content, encoding
        case htmlUrl = "html_url"
    }

    /// デコードされたテキストコンテンツ
    var decodedContent: String? {
        guard encoding == "base64" else { return content }
        // GitHub APIはBase64に改行を含むため除去
        let cleanBase64 = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleanBase64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - GitHub Branch
struct GitHubBranch: Codable, Identifiable {
    var id: String { name }
    let name: String

    struct Commit: Codable {
        let sha: String
    }
    let commit: Commit
}

// MARK: - GitHub Commit Response
struct GitHubCommitResponse: Codable {
    let content: GitHubContent?
    let commit: CommitInfo

    struct CommitInfo: Codable {
        let sha: String
        let message: String
        let htmlUrl: String?

        enum CodingKeys: String, CodingKey {
            case sha, message
            case htmlUrl = "html_url"
        }
    }
}

// MARK: - GitHub Search Result
struct GitHubSearchResult: Codable {
    let totalCount: Int
    let items: [GitHubRepository]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

// MARK: - File Create Request Model (UI用)
struct FileCreateRequest {
    var filename: String = ""
    var content: String = ""
    var commitMessage: String = ""
    var targetBranch: String = ""
    var targetPath: String = ""

    var isValid: Bool {
        !filename.isEmpty && !content.isEmpty && !commitMessage.isEmpty
    }

    var fullPath: String {
        if targetPath.isEmpty {
            return filename
        }
        return "\(targetPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(filename)"
    }
}
