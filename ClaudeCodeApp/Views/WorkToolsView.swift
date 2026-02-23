import SwiftUI

// MARK: - Work Tools Hub
/// 職業別仕事ツール画面
struct WorkToolsView: View {
    let workType: WorkType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch workType {
                    case .powerCompany:
                        PowerCompanyToolsView()
                    case .teacher:
                        TeacherToolsView()
                    default:
                        GenericWorkToolsView()
                    }
                }
                .padding()
            }
            .navigationTitle("\(workType.emoji) \(workType.displayName)ツール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: ⚡ 電力会社ツール
// MARK: ─────────────────────────────────────────
struct PowerCompanyToolsView: View {
    var body: some View {
        VStack(spacing: 20) {
            WorkToolSection(title: "📋 現場・点検", tools: [
                WorkToolCard(emoji: "🔍", title: "設備点検レポート",
                             desc: "点検内容を入力 → 正式な点検報告書を生成",
                             destination: AnyView(InspectionReportView())),
                WorkToolCard(emoji: "⚠️", title: "障害・トラブル報告書",
                             desc: "発生状況を入力 → 系統的なトラブル報告書を作成",
                             destination: AnyView(TroubleReportView())),
                WorkToolCard(emoji: "🦺", title: "KY活動記録",
                             desc: "作業内容を入力 → 危険予知活動の記録を生成",
                             destination: AnyView(KYActivityView())),
                WorkToolCard(emoji: "📅", title: "作業日報",
                             desc: "今日の作業内容 → 日報フォーマットに整形",
                             destination: AnyView(PowerDailyReportView())),
            ])

            WorkToolSection(title: "🏢 事務・対応", tools: [
                WorkToolCard(emoji: "👥", title: "お客様対応メモ",
                             desc: "問い合わせ内容 → 対応記録・回答案を作成",
                             destination: AnyView(CustomerResponseView())),
                WorkToolCard(emoji: "🔌", title: "停電対応記録",
                             desc: "停電状況を入力 → 対応経緯・復旧報告書を作成",
                             destination: AnyView(OutageReportView())),
                WorkToolCard(emoji: "📊", title: "月次業務報告",
                             desc: "実績数値・トピックを入力 → 月報を生成",
                             destination: AnyView(MonthlyReportView())),
                WorkToolCard(emoji: "🔧", title: "工事計画書",
                             desc: "工事内容を入力 → 作業計画書・工程表を作成",
                             destination: AnyView(WorkPlanView())),
            ])
        }
    }
}

// MARK: ⚡ 設備点検レポート
struct InspectionReportView: View {
    @State private var equipmentName = ""
    @State private var location = ""
    @State private var inspectionDate = Date()
    @State private var inspector = ""
    @State private var findings = ""
    @State private var judgement: Judgement = .normal
    @State private var action = ""
    @State private var result = ""
    @State private var isProcessing = false

    enum Judgement: String, CaseIterable {
        case normal   = "異常なし"
        case caution  = "要注意"
        case repair   = "要修繕"
        case urgent   = "緊急対応要"

        var color: Color {
            switch self {
            case .normal:  return .green
            case .caution: return .yellow
            case .repair:  return .orange
            case .urgent:  return .red
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "設備・場所") {
                    WorkTextField("設備名", text: $equipmentName, placeholder: "例：6.6kV配電変圧器 T-101")
                    WorkTextField("設置場所", text: $location, placeholder: "例：○○変電所 1号館 東側")
                    WorkTextField("点検者名", text: $inspector, placeholder: "例：山田 太郎")
                    DatePicker("点検日", selection: $inspectionDate, displayedComponents: .date)
                        .padding(.horizontal)
                }

                WorkFormSection(title: "点検結果") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("判定").font(.subheadline).bold().padding(.horizontal)
                        HStack(spacing: 8) {
                            ForEach(Judgement.allCases, id: \.self) { j in
                                Button {
                                    judgement = j
                                } label: {
                                    Text(j.rawValue)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(judgement == j ? j.color : Color(.systemGray5))
                                        .foregroundColor(judgement == j ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    WorkTextArea("点検内容・異常箇所", text: $findings,
                                 placeholder: "例：外観点検にて絶縁油の滲みを確認。漏油量は微量。")
                    WorkTextArea("処置・対応", text: $action,
                                 placeholder: "例：次回定期点検時に絶縁油補充を実施予定。当面は経過観察。")
                }

                WorkGenerateButton(label: "点検報告書を作成", isProcessing: isProcessing,
                                   disabled: equipmentName.isEmpty || findings.isEmpty) {
                    generate()
                }

                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🔍 設備点検レポート")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .long; df.locale = Locale(identifier: "ja_JP")
        let prompt = """
        以下の情報をもとに電力会社の正式な設備点検報告書を作成してください。

        【設備名】\(equipmentName)
        【設置場所】\(location)
        【点検日】\(df.string(from: inspectionDate))
        【点検者】\(inspector)
        【判定】\(judgement.rawValue)
        【点検内容・異常箇所】\(findings)
        【処置・対応】\(action.isEmpty ? "処置なし（経過観察）" : action)

        電力会社の業務文書として適切な書式・文体（ですます調、専門用語使用）で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ 障害・トラブル報告書
struct TroubleReportView: View {
    @State private var occurrenceDate = Date()
    @State private var location = ""
    @State private var equipment = ""
    @State private var symptom = ""
    @State private var cause = ""
    @State private var impact = ""
    @State private var response = ""
    @State private var prevention = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "発生状況") {
                    DatePicker("発生日時", selection: $occurrenceDate)
                        .padding(.horizontal)
                    WorkTextField("発生場所", text: $location, placeholder: "例：○○変電所 2号バンク")
                    WorkTextField("関係設備", text: $equipment, placeholder: "例：主変圧器 T-2、保護リレー")
                    WorkTextArea("症状・現象", text: $symptom,
                                 placeholder: "例：過電流リレー動作により送電停止。XX系統 停電範囲XXkW")
                }

                WorkFormSection(title: "原因・対応") {
                    WorkTextArea("推定原因", text: $cause,
                                 placeholder: "例：落雷による過渡電圧サージと推定")
                    WorkTextArea("影響範囲", text: $impact,
                                 placeholder: "例：需要家XX戸、最大停電時間XX分")
                    WorkTextArea("応急処置・復旧対応", text: $response,
                                 placeholder: "例：バイパス送電後、設備点検し異常なしを確認のうえ復旧")
                    WorkTextArea("再発防止策", text: $prevention,
                                 placeholder: "例：避雷器の点検強化、保護リレー整定値の見直し")
                }

                WorkGenerateButton(label: "トラブル報告書を作成", isProcessing: isProcessing,
                                   disabled: symptom.isEmpty || response.isEmpty) {
                    generate()
                }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("⚠️ 障害・トラブル報告書")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        df.locale = Locale(identifier: "ja_JP")
        let prompt = """
        以下の内容で電力会社の障害・トラブル報告書を作成してください。

        【発生日時】\(df.string(from: occurrenceDate))
        【発生場所】\(location)
        【関係設備】\(equipment)
        【症状・現象】\(symptom)
        【推定原因】\(cause.isEmpty ? "調査中" : cause)
        【影響範囲】\(impact.isEmpty ? "調査中" : impact)
        【応急処置・復旧対応】\(response)
        【再発防止策】\(prevention.isEmpty ? "検討中" : prevention)

        電力会社の公式報告書として、適切な書式（番号・見出し付き）・文体で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ KY活動記録
struct KYActivityView: View {
    @State private var workDate = Date()
    @State private var workLocation = ""
    @State private var workContent = ""
    @State private var workers = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "作業情報") {
                    DatePicker("作業日", selection: $workDate, displayedComponents: .date)
                        .padding(.horizontal)
                    WorkTextField("作業場所", text: $workLocation, placeholder: "例：○○変電所 高圧盤エリア")
                    WorkTextField("作業者（全員）", text: $workers, placeholder: "例：山田、鈴木、田中（計3名）")
                    WorkTextArea("作業内容", text: $workContent,
                                 placeholder: "例：6kV高圧ケーブル接続作業、活線近接作業あり")
                }

                // KYとは
                VStack(alignment: .leading, spacing: 6) {
                    Label("KY活動とは？", systemImage: "info.circle").font(.caption.bold())
                    Text("「危険予知」活動。作業前に潜在する危険を予測・確認し、安全対策を全員で共有する電力業界標準の安全管理手法です。")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.06))
                .cornerRadius(10)
                .padding(.horizontal)

                WorkGenerateButton(label: "KY活動記録を生成", isProcessing: isProcessing,
                                   disabled: workContent.isEmpty) {
                    generate()
                }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🦺 KY活動記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .long; df.locale = Locale(identifier: "ja_JP")
        let prompt = """
        以下の電力会社の作業に関するKY（危険予知）活動記録シートを作成してください。

        【作業日】\(df.string(from: workDate))
        【作業場所】\(workLocation)
        【作業者】\(workers.isEmpty ? "記載なし" : workers)
        【作業内容】\(workContent)

        以下の形式で出力してください：
        1. 本日の作業概要
        2. 危険ポイント（3〜5項目）：それぞれ「どんな危険か」「なぜ危険か」
        3. 安全対策・行動目標（各危険ポイントに対応）
        4. 指差し呼称ポイント
        5. 今日のひと言（安全へのコミットメント）

        電力現場の専門用語・保安規程に準拠した内容で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ 作業日報
struct PowerDailyReportView: View {
    @State private var reportDate = Date()
    @State private var workItems = ""
    @State private var achievements = ""
    @State private var issues = ""
    @State private var tomorrow = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "日報情報") {
                    DatePicker("日付", selection: $reportDate, displayedComponents: .date)
                        .padding(.horizontal)
                    WorkTextArea("本日の作業内容", text: $workItems,
                                 placeholder: "・○○変電所 月次定期点検\n・○○地区 設備巡視\n・工事立会い（○○工事）")
                    WorkTextArea("実績・成果", text: $achievements,
                                 placeholder: "例：定期点検完了。軽微な不具合1件を発見・報告。")
                    WorkTextArea("課題・申し送り", text: $issues,
                                 placeholder: "例：T-3変圧器の絶縁油に変色あり。来週精密点検予定。")
                    WorkTextArea("明日の予定", text: $tomorrow,
                                 placeholder: "例：○○変電所 精密点検、午後は○○工事立会い")
                }

                WorkGenerateButton(label: "日報を作成", isProcessing: isProcessing,
                                   disabled: workItems.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📅 作業日報")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .full; df.locale = Locale(identifier: "ja_JP")
        let prompt = """
        以下の情報をもとに電力会社社員の作業日報を作成してください。

        【日付】\(df.string(from: reportDate))
        【本日の作業内容】\n\(workItems)
        【実績・成果】\(achievements.isEmpty ? "特記事項なし" : achievements)
        【課題・申し送り】\(issues.isEmpty ? "特になし" : issues)
        【明日の予定】\(tomorrow.isEmpty ? "未定" : tomorrow)

        読みやすく整理された日報形式（です・ます調）で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ お客様対応メモ
struct CustomerResponseView: View {
    @State private var inquiryType: InquiryType = .outage
    @State private var situation = ""
    @State private var outputType: CustomerOutputType = .response

    @State private var result = ""
    @State private var isProcessing = false

    enum InquiryType: String, CaseIterable {
        case outage    = "停電の問い合わせ"
        case billing   = "料金・請求"
        case contract  = "契約変更"
        case facility  = "設備・工事"
        case complaint = "クレーム・苦情"
        case other     = "その他"
    }

    enum CustomerOutputType: String, CaseIterable {
        case response = "回答・対応案"
        case memo     = "対応記録メモ"
        case report   = "上長への報告文"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "問い合わせ内容") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("種別").font(.subheadline).bold().padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(InquiryType.allCases, id: \.self) { t in
                                    Button { inquiryType = t } label: {
                                        Text(t.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(inquiryType == t ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(inquiryType == t ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    WorkTextArea("状況・内容", text: $situation,
                                 placeholder: "例：昨日から停電している。冷蔵庫の食品が傷んだ。補償を求めたい。")
                }

                WorkFormSection(title: "出力形式") {
                    Picker("", selection: $outputType) {
                        ForEach(CustomerOutputType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                WorkGenerateButton(label: "作成する", isProcessing: isProcessing,
                                   disabled: situation.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("👥 お客様対応")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        電力会社のカスタマーサービス担当者として、以下のお客様対応について「\(outputType.rawValue)」を作成してください。

        【問い合わせ種別】\(inquiryType.rawValue)
        【状況・内容】\(situation)

        電力会社の標準的な対応方針・法令（電気事業法等）を踏まえた内容で、丁寧かつ的確に作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ 停電対応記録
struct OutageReportView: View {
    @State private var startTime  = Date()
    @State private var endTime    = Date()
    @State private var area       = ""
    @State private var affectedCount = ""
    @State private var cause      = ""
    @State private var response   = ""
    @State private var result     = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "停電情報") {
                    DatePicker("停電開始日時", selection: $startTime).padding(.horizontal)
                    DatePicker("復旧日時",     selection: $endTime).padding(.horizontal)
                    WorkTextField("停電エリア", text: $area,
                                  placeholder: "例：○○市○○町 一丁目〜三丁目")
                    WorkTextField("影響戸数・需要家", text: $affectedCount,
                                  placeholder: "例：一般家庭 約320戸、事業所 8件")
                    WorkTextArea("原因", text: $cause,
                                 placeholder: "例：配電線への倒木接触による地絡事故")
                    WorkTextArea("復旧対応", text: $response,
                                 placeholder: "例：倒木除去後、区間切替による迂回送電。損傷電線の取替工事を実施。")
                }

                WorkGenerateButton(label: "停電対応報告書を作成", isProcessing: isProcessing,
                                   disabled: area.isEmpty || response.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🔌 停電対応記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        df.locale = Locale(identifier: "ja_JP")
        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
        let prompt = """
        以下の内容で停電対応報告書を作成してください。

        【停電開始】\(df.string(from: startTime))
        【復旧日時】\(df.string(from: endTime))（停電時間：約\(duration)分）
        【停電エリア】\(area)
        【影響戸数】\(affectedCount.isEmpty ? "調査中" : affectedCount)
        【原因】\(cause.isEmpty ? "調査中" : cause)
        【復旧対応】\(response)

        電力会社の公式報告書として適切な書式・用語で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ 月次業務報告
struct MonthlyReportView: View {
    @State private var yearMonth = ""
    @State private var inspections = ""
    @State private var troubles = ""
    @State private var achievements = ""
    @State private var nextMonth = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "月次報告") {
                    WorkTextField("対象年月", text: $yearMonth, placeholder: "例：2025年12月")
                    WorkTextArea("点検実績", text: $inspections,
                                 placeholder: "例：定期点検12件、臨時点検3件 計15件実施。異常1件（要注意）")
                    WorkTextArea("トラブル・障害", text: $troubles,
                                 placeholder: "例：停電事故1件（○○地区、原因：倒木）、復旧まで45分")
                    WorkTextArea("その他実績・トピック", text: $achievements,
                                 placeholder: "例：新規設備導入立会い2件、研修参加1件")
                    WorkTextArea("来月の予定・課題", text: $nextMonth,
                                 placeholder: "例：年次点検シーズン開始、老朽設備更新工事着手予定")
                }

                WorkGenerateButton(label: "月次報告書を作成", isProcessing: isProcessing,
                                   disabled: yearMonth.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📊 月次業務報告")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        以下の情報をもとに電力会社の月次業務報告書を作成してください。

        【対象年月】\(yearMonth)
        【点検実績】\(inspections.isEmpty ? "特記事項なし" : inspections)
        【トラブル・障害】\(troubles.isEmpty ? "発生なし" : troubles)
        【その他実績】\(achievements.isEmpty ? "特記事項なし" : achievements)
        【来月の予定・課題】\(nextMonth.isEmpty ? "通常業務予定" : nextMonth)

        見出しと表を活用し、上長への報告に適した月次報告書形式で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ⚡ 工事計画書
struct WorkPlanView: View {
    @State private var workName   = ""
    @State private var workDate   = Date()
    @State private var location   = ""
    @State private var workers    = ""
    @State private var workDetail = ""
    @State private var equipment  = ""
    @State private var result     = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "工事情報") {
                    WorkTextField("工事名", text: $workName,
                                  placeholder: "例：○○変電所 高圧ケーブル取替工事")
                    DatePicker("施工予定日", selection: $workDate, displayedComponents: .date)
                        .padding(.horizontal)
                    WorkTextField("施工場所", text: $location,
                                  placeholder: "例：○○変電所 地中引込線 A系統")
                    WorkTextField("作業員（人数）", text: $workers,
                                  placeholder: "例：電気工事士2名、補助作業員1名 計3名")
                    WorkTextArea("作業内容・手順", text: $workDetail,
                                 placeholder: "例：既設ケーブル撤去→新設ケーブル布設→接続→絶縁試験→通電確認")
                    WorkTextArea("使用機材・工具", text: $equipment,
                                 placeholder: "例：ケーブルドラム、圧縮工具、絶縁抵抗計")
                }

                WorkGenerateButton(label: "工事計画書を作成", isProcessing: isProcessing,
                                   disabled: workName.isEmpty || workDetail.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🔧 工事計画書")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .long; df.locale = Locale(identifier: "ja_JP")
        let prompt = """
        以下の内容で電力工事の作業計画書を作成してください。

        【工事名】\(workName)
        【施工予定日】\(df.string(from: workDate))
        【施工場所】\(location)
        【作業員】\(workers.isEmpty ? "未定" : workers)
        【作業内容・手順】\(workDetail)
        【使用機材・工具】\(equipment.isEmpty ? "標準工具一式" : equipment)

        安全対策・停電操作手順・復電確認手順も含めた正式な電力工事作業計画書を作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.powerCompany.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: ─────────────────────────────────────────
// MARK: 📚 高校教師ツール
// MARK: ─────────────────────────────────────────
struct TeacherToolsView: View {
    var body: some View {
        VStack(spacing: 20) {
            WorkToolSection(title: "📖 授業・教材", tools: [
                WorkToolCard(emoji: "📖", title: "学習指導案",
                             desc: "単元・ねらいを入力 → 正式な指導案を生成",
                             destination: AnyView(LessonPlanView())),
                WorkToolCard(emoji: "📝", title: "テスト問題作成",
                             desc: "単元・種別を選択 → 問題と解答・解説を生成",
                             destination: AnyView(TestMakerView())),
                WorkToolCard(emoji: "📄", title: "学習プリント",
                             desc: "テーマを入力 → 穴埋め・練習問題プリントを作成",
                             destination: AnyView(WorksheetView())),
                WorkToolCard(emoji: "🗒️", title: "授業振り返りシート",
                             desc: "授業内容を入力 → 生徒用振り返りシートを生成",
                             destination: AnyView(ReflectionSheetView())),
            ])

            WorkToolSection(title: "🏫 学校・学級", tools: [
                WorkToolCard(emoji: "📋", title: "通知表コメント",
                             desc: "生徒の特徴・成績を入力 → 所見文を生成",
                             destination: AnyView(ReportCardCommentView())),
                WorkToolCard(emoji: "📬", title: "保護者向け連絡文",
                             desc: "状況を入力 → 丁寧な保護者向け文書を作成",
                             destination: AnyView(ParentLetterView())),
                WorkToolCard(emoji: "📅", title: "学校行事計画",
                             desc: "行事内容を入力 → 実施計画書・役割分担表を作成",
                             destination: AnyView(SchoolEventPlanView())),
                WorkToolCard(emoji: "🗣️", title: "生徒指導記録",
                             desc: "指導内容を入力 → 適切な記録文書を作成",
                             destination: AnyView(StudentGuidanceView())),
            ])
        }
    }
}

// MARK: 📚 学習指導案
struct LessonPlanView: View {
    @State private var subject    = ""
    @State private var grade      = "1年"
    @State private var unit       = ""
    @State private var lesson     = ""
    @State private var objectives = ""
    @State private var duration   = "50分"
    @State private var style: LessonStyle = .standard

    @State private var result = ""
    @State private var isProcessing = false

    let grades = ["1年", "2年", "3年"]
    let durations = ["45分", "50分", "100分（2コマ）"]

    enum LessonStyle: String, CaseIterable {
        case standard   = "標準授業"
        case research   = "研究授業"
        case ict        = "ICT活用"
        case discussion = "ディスカッション型"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "授業情報") {
                    WorkTextField("教科", text: $subject,
                                  placeholder: "例：数学、英語、現代文、物理")
                    HStack {
                        Text("学年").font(.subheadline).bold().padding(.leading)
                        Picker("", selection: $grade) {
                            ForEach(grades, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented)
                        Picker("授業時間", selection: $duration) {
                            ForEach(durations, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                    }
                    .padding(.horizontal)
                    WorkTextField("単元名", text: $unit,
                                  placeholder: "例：二次関数、現在完了形、源氏物語")
                    WorkTextField("本時のテーマ・課題", text: $lesson,
                                  placeholder: "例：二次関数のグラフの頂点を求める")
                    WorkTextArea("本時のねらい（目標）", text: $objectives,
                                 placeholder: "例：・平方完成を使って頂点の座標を求められる\n・グラフの平行移動を理解する")
                }

                WorkFormSection(title: "授業スタイル") {
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LessonStyle.allCases, id: \.self) { s in
                                    Button { style = s } label: {
                                        Text(s.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(style == s ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(style == s ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                WorkGenerateButton(label: "学習指導案を作成", isProcessing: isProcessing,
                                   disabled: subject.isEmpty || unit.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📖 学習指導案")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        以下の情報をもとに高校の学習指導案を作成してください。

        【教科】\(subject)　【学年】高校\(grade)　【授業時間】\(duration)
        【単元名】\(unit)
        【本時のテーマ・課題】\(lesson.isEmpty ? unit : lesson)
        【本時のねらい】\(objectives.isEmpty ? "基本的な理解と活用" : objectives)
        【授業スタイル】\(style.rawValue)

        文部科学省の学習指導要領に準拠し、以下の形式で作成してください：
        1. 単元の目標と評価規準
        2. 本時の目標
        3. 本時の展開（導入・展開・まとめ、各段階の教師の活動・生徒の活動・指導上の留意点）
        4. 板書計画
        5. 評価方法
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 テスト問題作成
struct TestMakerView: View {
    @State private var subject  = ""
    @State private var unit     = ""
    @State private var grade    = "1年"
    @State private var types: Set<QuestionType> = [.multipleChoice, .shortAnswer]
    @State private var count    = 10
    @State private var difficulty: Difficulty = .standard
    @State private var result   = ""
    @State private var isProcessing = false

    let grades = ["1年", "2年", "3年"]

    enum QuestionType: String, CaseIterable, Hashable {
        case multipleChoice = "選択問題"
        case shortAnswer    = "記述・穴埋め"
        case essay          = "論述問題"
        case calculation    = "計算問題"
        case reading        = "読解問題"
    }

    enum Difficulty: String, CaseIterable {
        case basic    = "基本"
        case standard = "標準"
        case advanced = "発展"
        case mixed    = "混合"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "テスト情報") {
                    WorkTextField("教科", text: $subject,
                                  placeholder: "例：数学Ⅱ、英語コミュニケーション")
                    HStack {
                        Text("学年").font(.subheadline).bold().padding(.leading)
                        Picker("", selection: $grade) {
                            ForEach(grades, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented).padding(.trailing)
                    }
                    .padding(.horizontal)
                    WorkTextArea("出題範囲・単元", text: $unit,
                                 placeholder: "例：三角関数（定義〜加法定理）\n教科書 pp.120〜145")
                    HStack {
                        Text("問題数").font(.subheadline).bold().padding(.leading)
                        Stepper("\(count)問", value: $count, in: 5...25).padding(.trailing)
                    }
                    .padding(.horizontal)
                }

                WorkFormSection(title: "問題種別（複数選択可）") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(QuestionType.allCases, id: \.self) { t in
                            Button {
                                if types.contains(t) { types.remove(t) }
                                else { types.insert(t) }
                            } label: {
                                Text(t.rawValue)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(types.contains(t) ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(types.contains(t) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                WorkFormSection(title: "難易度") {
                    Picker("難易度", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented).padding(.horizontal)
                }

                WorkGenerateButton(label: "テスト問題を作成", isProcessing: isProcessing,
                                   disabled: subject.isEmpty || unit.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📝 テスト問題作成")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let typeList = types.map(\.rawValue).joined(separator: "・")
        let prompt = """
        高校\(grade)【\(subject)】のテスト問題を\(count)問作成してください。

        【出題範囲】\(unit)
        【問題種別】\(typeList)
        【難易度】\(difficulty.rawValue)

        各問題に配点・解答・解説も付けてください。
        実際に使用できる本格的なテスト形式で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 通知表コメント
struct ReportCardCommentView: View {
    @State private var studentDesc = ""
    @State private var subject     = ""
    @State private var grade: Grade = .a
    @State private var term: Term   = .first
    @State private var count        = 3
    @State private var result       = ""
    @State private var isProcessing = false

    enum Grade: String, CaseIterable {
        case aPlus = "大変優れている"
        case a     = "優れている"
        case b     = "おおむね良好"
        case c     = "努力が必要"
    }

    enum Term: String, CaseIterable {
        case first  = "1学期"
        case second = "2学期"
        case third  = "3学期"
        case year   = "年度末"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "生徒の情報") {
                    WorkTextField("教科（任意）", text: $subject,
                                  placeholder: "例：数学、英語、担任所見 など")
                    WorkTextArea("生徒の特徴・エピソード",
                                 text: $studentDesc,
                                 placeholder: "例：・授業中の発言が積極的\n・テスト結果は中程度だが、提出物は丁寧\n・文化祭で積極的にリーダー役を担った")
                }

                WorkFormSection(title: "評価・学期") {
                    HStack {
                        Text("評定").font(.subheadline).bold().padding(.leading)
                        Picker("", selection: $grade) {
                            ForEach(Grade.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }.pickerStyle(.menu).padding(.trailing)
                    }
                    .padding(.horizontal)
                    HStack {
                        Text("学期").font(.subheadline).bold().padding(.leading)
                        Picker("", selection: $term) {
                            ForEach(Term.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }.pickerStyle(.segmented).padding(.trailing)
                    }
                    .padding(.horizontal)
                    HStack {
                        Text("候補数").font(.subheadline).bold().padding(.leading)
                        Stepper("\(count)パターン", value: $count, in: 1...5).padding(.trailing)
                    }
                    .padding(.horizontal)
                }

                WorkGenerateButton(label: "所見コメントを生成", isProcessing: isProcessing,
                                   disabled: studentDesc.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📋 通知表コメント")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        高校の通知表所見コメントを\(count)パターン生成してください。

        【教科・区分】\(subject.isEmpty ? "総合所見" : subject)
        【学期】\(term.rawValue)
        【評定】\(grade.rawValue)
        【生徒の特徴・エピソード】\(studentDesc)

        各コメントは80〜120文字程度、保護者が読んで前向きになれる表現で。
        ポジティブな表現を基本にしつつ、課題がある場合は「〜するとさらに良くなります」などの前向きな言い回しで。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 保護者連絡文
struct ParentLetterView: View {
    @State private var purpose: LetterPurpose = .event
    @State private var content   = ""
    @State private var deadline  = ""
    @State private var result    = ""
    @State private var isProcessing = false

    enum LetterPurpose: String, CaseIterable {
        case event      = "学校行事のお知らせ"
        case absence    = "欠席・遅刻への連絡"
        case guidance   = "生徒指導に関する連絡"
        case gradeInfo  = "成績・進路の相談"
        case emergency  = "緊急連絡"
        case thanks     = "お礼・感謝"
        case other      = "その他"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "連絡内容") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("目的").font(.subheadline).bold().padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LetterPurpose.allCases, id: \.self) { p in
                                    Button { purpose = p } label: {
                                        Text(p.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(purpose == p ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(purpose == p ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    WorkTextArea("詳細内容", text: $content,
                                 placeholder: "例：来週の修学旅行（3泊4日・京都・奈良）の持ち物と集合場所について")
                    WorkTextField("締め切り・返信期限（任意）", text: $deadline,
                                  placeholder: "例：12月15日（金）まで")
                }

                WorkGenerateButton(label: "保護者連絡文を作成", isProcessing: isProcessing,
                                   disabled: content.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📬 保護者連絡文")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        高校から保護者への「\(purpose.rawValue)」の連絡文を作成してください。

        【内容】\(content)
        【締め切り】\(deadline.isEmpty ? "特になし" : deadline)

        学校らしい丁寧な文体（拝啓・敬具スタイルまたはビジネスレター形式）で、
        保護者に伝わりやすく・不安を与えない表現で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 学習プリント
struct WorksheetView: View {
    @State private var subject  = ""
    @State private var topic    = ""
    @State private var grade    = "1年"
    @State private var style: WorksheetStyle = .fillBlank
    @State private var result   = ""
    @State private var isProcessing = false

    let grades = ["1年", "2年", "3年"]

    enum WorksheetStyle: String, CaseIterable {
        case fillBlank   = "穴埋め"
        case qa          = "一問一答"
        case reading     = "読解・考察"
        case exercise    = "練習問題"
        case summary     = "まとめ用"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "プリント情報") {
                    WorkTextField("教科", text: $subject, placeholder: "例：現代社会、生物基礎")
                    HStack {
                        Text("学年").font(.subheadline).bold().padding(.leading)
                        Picker("", selection: $grade) {
                            ForEach(grades, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented).padding(.trailing)
                    }
                    .padding(.horizontal)
                    WorkTextArea("単元・テーマ", text: $topic,
                                 placeholder: "例：細胞の構造と機能、光合成のしくみ")
                }

                WorkFormSection(title: "プリントの種類") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(WorksheetStyle.allCases, id: \.self) { s in
                            Button { style = s } label: {
                                Text(s.rawValue)
                                    .font(.caption).frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(style == s ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(style == s ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                WorkGenerateButton(label: "学習プリントを作成", isProcessing: isProcessing,
                                   disabled: subject.isEmpty || topic.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📄 学習プリント")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        高校\(grade)【\(subject)】の学習プリントを作成してください。

        【単元・テーマ】\(topic)
        【形式】\(style.rawValue)

        印刷してそのまま使えるフォーマットで、解答欄付きで作成してください。
        内容は高校\(grade)生のレベルに合わせてください。
        最後に解答例も記載してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 授業振り返りシート
struct ReflectionSheetView: View {
    @State private var subject  = ""
    @State private var lesson   = ""
    @State private var grade    = "1年"
    @State private var result   = ""
    @State private var isProcessing = false
    let grades = ["1年", "2年", "3年"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "授業情報") {
                    WorkTextField("教科", text: $subject, placeholder: "例：数学、英語")
                    HStack {
                        Text("学年").font(.subheadline).bold().padding(.leading)
                        Picker("", selection: $grade) {
                            ForEach(grades, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented).padding(.trailing)
                    }
                    .padding(.horizontal)
                    WorkTextArea("今日の授業内容", text: $lesson,
                                 placeholder: "例：連立方程式の解き方（代入法・加減法）を学習した")
                }
                WorkGenerateButton(label: "振り返りシートを生成", isProcessing: isProcessing,
                                   disabled: subject.isEmpty || lesson.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🗒️ 授業振り返りシート")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        以下の授業についての生徒用「振り返りシート」を作成してください。

        【教科】\(subject)　【学年】高校\(grade)
        【今日の授業内容】\(lesson)

        生徒が自己評価・気づき・疑問を記録できる振り返りシートを作成してください。
        ルーブリックや評価の観点も含めてください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 学校行事計画
struct SchoolEventPlanView: View {
    @State private var eventName = ""
    @State private var date      = Date()
    @State private var target    = ""
    @State private var purpose   = ""
    @State private var result    = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "行事情報") {
                    WorkTextField("行事名", text: $eventName,
                                  placeholder: "例：体育祭、文化祭、修学旅行、球技大会")
                    DatePicker("実施予定日", selection: $date, displayedComponents: .date)
                        .padding(.horizontal)
                    WorkTextField("対象学年・人数", text: $target,
                                  placeholder: "例：全校生徒 約600名 / 2年生 200名")
                    WorkTextArea("目的・ねらい", text: $purpose,
                                 placeholder: "例：クラスの絆を深め、協働する力を育む")
                }
                WorkGenerateButton(label: "行事計画書を作成", isProcessing: isProcessing,
                                   disabled: eventName.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📅 学校行事計画")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let df = DateFormatter(); df.dateStyle = .long; df.locale = Locale(identifier: "ja_JP")
        let prompt = """
        高校の「\(eventName)」の実施計画書を作成してください。

        【実施日】\(df.string(from: date))
        【対象】\(target.isEmpty ? "全校生徒" : target)
        【目的・ねらい】\(purpose.isEmpty ? "生徒の成長と交流" : purpose)

        タイムスケジュール、役割分担、準備事項、注意事項を含めた実施計画書を作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: 📚 生徒指導記録
struct StudentGuidanceView: View {
    @State private var situation = ""
    @State private var outputType: GuidanceOutput = .record
    @State private var result    = ""
    @State private var isProcessing = false

    enum GuidanceOutput: String, CaseIterable {
        case record    = "指導記録"
        case letter    = "保護者連絡"
        case plan      = "支援計画"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorkFormSection(title: "状況・内容") {
                    WorkTextArea("状況", text: $situation,
                                 placeholder: "例：授業中の立ち歩き・離席が続いている。本人に確認したところ「授業がわからない」と話した。")
                }
                WorkFormSection(title: "出力形式") {
                    Picker("", selection: $outputType) {
                        ForEach(GuidanceOutput.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented).padding(.horizontal)
                }
                WorkGenerateButton(label: "作成する", isProcessing: isProcessing,
                                   disabled: situation.isEmpty) { generate() }
                if !result.isEmpty { WorkResultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🗣️ 生徒指導記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isProcessing = true; result = ""
        let prompt = """
        以下の状況をもとに、高校の「\(outputType.rawValue)」を作成してください。

        【状況】\(situation)

        生徒のプライバシーに配慮しつつ、教育的・支援的な視点で作成してください。
        """
        Task {
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: WorkType.teacher.systemPromptContext
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - Generic Work Tools
struct GenericWorkToolsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("📋").font(.system(size: 50))
            Text("プロフィール設定で職業を選ぶと\n専用ツールが表示されます")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
}

// MARK: ─────────────────────────────────────────
// MARK: Shared UI Components
// MARK: ─────────────────────────────────────────

struct WorkToolSection: View {
    let title: String
    let tools: [WorkToolCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(tools) { tool in
                    NavigationLink(destination: tool.destination) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tool.emoji).font(.title2)
                            Text(tool.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(tool.desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                }
            }
        }
    }
}

struct WorkToolCard: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let desc: String
    let destination: AnyView
}

// MARK: - Form Helper Views
struct WorkFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal)
            content()
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal)
    }
}

struct WorkTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundColor(.secondary).padding(.horizontal)
            TextField(placeholder, text: $text)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }
}

struct WorkTextArea: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundColor(.secondary).padding(.horizontal)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.callout)
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                }
                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}

struct WorkGenerateButton: View {
    let label: String
    let isProcessing: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView().tint(.white).scaleEffect(0.9)
                } else {
                    Image(systemName: "wand.and.sparkles")
                }
                Text(isProcessing ? "作成中..." : label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? Color(.systemGray4) : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal)
        }
        .disabled(disabled || isProcessing)
    }
}

func WorkResultCard(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Label("生成結果", systemImage: "sparkles").font(.headline)
            Spacer()
            Button { UIPasteboard.general.string = text } label: {
                Label("コピー", systemImage: "doc.on.doc").font(.caption)
            }
            ShareLink(item: text) {
                Label("共有", systemImage: "square.and.arrow.up").font(.caption)
            }
        }
        ScrollView {
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(14)
    .padding(.horizontal)
}
