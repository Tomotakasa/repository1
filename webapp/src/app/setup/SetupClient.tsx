'use client'

export default function SetupClient() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 to-blue-950 p-4">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md">
        <div className="w-12 h-12 bg-gradient-to-br from-violet-500 to-blue-500 rounded-xl flex items-center justify-center text-white font-bold mx-auto mb-5">
          AI
        </div>
        <h1 className="text-xl font-bold text-gray-800 text-center mb-1">初回セットアップ</h1>
        <p className="text-gray-400 text-sm text-center mb-6">Vercelに環境変数を設定してください</p>

        <div className="space-y-4 text-sm text-gray-700">
          <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
            <p className="font-semibold text-blue-800 mb-2">Vercel 環境変数の設定</p>
            <ol className="list-decimal list-inside space-y-2 text-blue-700">
              <li>Vercel Dashboard → Settings → Environment Variables を開く</li>
              <li>以下の変数を追加してRedeploy</li>
            </ol>
          </div>

          <div className="space-y-2">
            {[
              { key: 'ADMIN_PASSWORD', desc: '管理者パスワード（必須）' },
              { key: 'GUEST_PASSWORD', desc: 'ゲストパスワード（任意）' },
              { key: 'AUTH_SECRET', desc: 'ランダムな秘密鍵（必須）' },
              { key: 'ANTHROPIC_API_KEY', desc: 'Anthropic APIキー（必須）' },
            ].map(({ key, desc }) => (
              <div key={key} className="bg-gray-50 rounded-xl p-3">
                <code className="text-xs font-bold text-gray-800">{key}</code>
                <p className="text-xs text-gray-500 mt-0.5">{desc}</p>
              </div>
            ))}
          </div>

          <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 text-xs text-amber-700">
            AUTH_SECRET は <code className="bg-amber-100 px-1 rounded">openssl rand -base64 32</code> などで生成したランダムな文字列を使ってください
          </div>
        </div>
      </div>
    </div>
  )
}
