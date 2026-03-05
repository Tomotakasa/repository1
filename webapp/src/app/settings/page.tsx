'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Sidebar from '@/components/Sidebar'
import { Settings, DEFAULT_SETTINGS, CLAUDE_MODELS, OLLAMA_MODELS, GROQ_MODELS, LLMBackend } from '@/lib/types'
import { loadSettings, saveSettings, clearHistory } from '@/lib/storage'

export default function SettingsPage() {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS)
  const [showCustomKey, setShowCustomKey] = useState(false)
  const [showGroqKey, setShowGroqKey] = useState(false)
  const [saved, setSaved] = useState(false)
  const [showClearConfirm, setShowClearConfirm] = useState(false)
  const [loggingOut, setLoggingOut] = useState(false)
  const router = useRouter()

  useEffect(() => {
    setSettings(loadSettings())
  }, [])

  function update(patch: Partial<Settings>) {
    setSettings(prev => ({ ...prev, ...patch }))
  }

  function handleSave() {
    saveSettings(settings)
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }

  function handleClearHistory() {
    clearHistory()
    setShowClearConfirm(false)
  }

  async function handleLogout() {
    setLoggingOut(true)
    await fetch('/api/auth/logout', { method: 'POST' })
    router.push('/login')
  }

  const backendOptions: { value: LLMBackend; label: string; desc: string }[] = [
    { value: 'claude', label: 'Claude API', desc: 'Anthropicのクラウド（最高品質）' },
    { value: 'groq', label: 'Groq（完全無料）', desc: '高速・無料APIキーで即使用可能' },
    { value: 'ollama', label: 'Ollama（ローカル）', desc: 'Mac上で完全オフライン実行' },
    { value: 'openai-compatible', label: 'OpenAI互換API', desc: 'カスタムサーバー対応' }
  ]

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar />
      <main className="flex-1 overflow-y-auto">
        <div className="max-w-2xl mx-auto px-6 py-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-8">設定</h1>

          {/* LLM バックエンド選択 */}
          <Section title="🤖 AIバックエンド">
            <div className="space-y-3">
              {backendOptions.map(opt => (
                <label key={opt.value}
                  className={`flex items-start gap-3 p-4 rounded-xl border-2 cursor-pointer transition-colors ${
                    settings.llmBackend === opt.value
                      ? 'border-blue-500 bg-blue-50'
                      : 'border-gray-200 bg-white hover:border-gray-300'
                  }`}
                >
                  <input
                    type="radio"
                    name="llmBackend"
                    value={opt.value}
                    checked={settings.llmBackend === opt.value}
                    onChange={() => update({ llmBackend: opt.value })}
                    className="mt-1 accent-blue-500"
                  />
                  <div>
                    <div className="font-semibold text-gray-800">{opt.label}</div>
                    <div className="text-sm text-gray-500">{opt.desc}</div>
                  </div>
                </label>
              ))}
            </div>
          </Section>

          {/* Claude API 設定 */}
          {settings.llmBackend === 'claude' && (
            <Section title="Claude API 設定">
              <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 text-sm text-blue-800">
                <p className="font-semibold mb-1">🔒 APIキーはサーバーで管理</p>
                <p>Claude APIキーはVercelの環境変数 <code className="bg-blue-100 px-1 rounded">CLAUDE_API_KEY</code> で安全に管理されています。ブラウザには送信されません。</p>
              </div>
              <Field label="モデル">
                <select
                  value={settings.claudeModel}
                  onChange={e => update({ claudeModel: e.target.value })}
                  className="w-full input"
                >
                  {CLAUDE_MODELS.map(m => (
                    <option key={m.id} value={m.id}>{m.label}</option>
                  ))}
                </select>
              </Field>
            </Section>
          )}

          {/* Groq 設定 */}
          {settings.llmBackend === 'groq' && (
            <Section title="Groq 設定（完全無料）">
              <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-sm text-green-800">
                <p className="font-semibold mb-2">無料APIキーの取得方法</p>
                <ol className="list-decimal list-inside space-y-1">
                  <li><a href="https://console.groq.com" target="_blank" rel="noopener noreferrer" className="underline">console.groq.com</a> でアカウント作成（無料）</li>
                  <li>「API Keys」メニューから新しいキーを作成</li>
                  <li>コピーして下記に貼り付け</li>
                </ol>
                <p className="mt-2 text-xs text-green-700">無料枠: 1日14,400リクエスト / 毎分30回まで</p>
              </div>
              <Field label="APIキー">
                <div className="relative">
                  <input
                    type={showGroqKey ? 'text' : 'password'}
                    value={settings.groqApiKey}
                    onChange={e => update({ groqApiKey: e.target.value })}
                    placeholder="gsk_..."
                    className="w-full pr-10 input"
                  />
                  <button
                    type="button"
                    onClick={() => setShowGroqKey(v => !v)}
                    className="absolute inset-y-0 right-2 text-gray-400 hover:text-gray-600"
                  >
                    {showGroqKey ? <EyeOffIcon /> : <EyeIcon />}
                  </button>
                </div>
              </Field>
              <Field label="モデル">
                <select
                  value={settings.groqModel}
                  onChange={e => update({ groqModel: e.target.value })}
                  className="w-full input"
                >
                  {GROQ_MODELS.map(m => (
                    <option key={m.id} value={m.id}>{m.label}</option>
                  ))}
                </select>
              </Field>
            </Section>
          )}

          {/* Ollama 設定 */}
          {settings.llmBackend === 'ollama' && (
            <Section title="Ollama 設定">
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-4 text-sm text-amber-800">
                <p className="font-semibold mb-2">Macでの起動方法（同じWi-Fi内）</p>
                <ol className="list-decimal list-inside space-y-1">
                  <li>Ollamaをインストール: <code className="bg-amber-100 px-1 rounded">brew install ollama</code></li>
                  <li>モデルを取得: <code className="bg-amber-100 px-1 rounded">ollama pull phi3:mini</code></li>
                  <li>サーバー起動: <code className="bg-amber-100 px-1 rounded">OLLAMA_HOST=0.0.0.0 ollama serve</code></li>
                  <li>MacのIPアドレスを下記に入力</li>
                </ol>
              </div>
              <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-4 text-sm text-blue-800">
                <p className="font-semibold mb-2">外出先からも使う場合（Tailscale）</p>
                <ol className="list-decimal list-inside space-y-1">
                  <li><a href="https://tailscale.com" target="_blank" rel="noopener noreferrer" className="underline">tailscale.com</a> で無料アカウント作成</li>
                  <li>Mac: <code className="bg-blue-100 px-1 rounded">brew install tailscale</code> → <code className="bg-blue-100 px-1 rounded">tailscale up</code></li>
                  <li>iPhone: App StoreでTailscaleをインストール → 同じアカウントでログイン</li>
                  <li>MacのTailscale IPアドレス（例: <code className="bg-blue-100 px-1 rounded">100.x.x.x</code>）を下記に入力</li>
                </ol>
                <p className="mt-2 text-xs text-blue-700">完全無料・どこからでもアクセス可能</p>
              </div>
              <Field label="エンドポイントURL" hint="同じWi-Fi: MacのローカルIP / 外出先: TailscaleのIP">
                <input
                  type="text"
                  value={settings.ollamaEndpoint}
                  onChange={e => update({ ollamaEndpoint: e.target.value })}
                  placeholder="http://192.168.1.10:11434"
                  className="w-full input"
                />
              </Field>
              <Field label="モデル">
                <select
                  value={settings.ollamaModel}
                  onChange={e => update({ ollamaModel: e.target.value })}
                  className="w-full input"
                >
                  {OLLAMA_MODELS.map(m => (
                    <option key={m.id} value={m.id}>{m.label}</option>
                  ))}
                </select>
              </Field>
            </Section>
          )}

          {/* カスタムAPI 設定 */}
          {settings.llmBackend === 'openai-compatible' && (
            <Section title="カスタムAPI 設定">
              <Field label="エンドポイントURL">
                <input
                  type="text"
                  value={settings.customEndpoint}
                  onChange={e => update({ customEndpoint: e.target.value })}
                  placeholder="https://your-server.com/v1"
                  className="w-full input"
                />
              </Field>
              <Field label="APIキー（任意）">
                <div className="relative">
                  <input
                    type={showCustomKey ? 'text' : 'password'}
                    value={settings.customApiKey}
                    onChange={e => update({ customApiKey: e.target.value })}
                    placeholder="（不要な場合は空欄）"
                    className="w-full pr-10 input"
                  />
                  <button
                    type="button"
                    onClick={() => setShowCustomKey(v => !v)}
                    className="absolute inset-y-0 right-2 text-gray-400 hover:text-gray-600"
                  >
                    {showCustomKey ? <EyeOffIcon /> : <EyeIcon />}
                  </button>
                </div>
              </Field>
              <Field label="モデル名">
                <input
                  type="text"
                  value={settings.customModel}
                  onChange={e => update({ customModel: e.target.value })}
                  placeholder="例: gpt-4o, llama3"
                  className="w-full input"
                />
              </Field>
            </Section>
          )}

          {/* データ管理 */}
          <Section title="📊 データ管理">
            {!showClearConfirm ? (
              <button
                onClick={() => setShowClearConfirm(true)}
                className="w-full py-2.5 px-4 rounded-xl border-2 border-red-300 text-red-600 font-medium hover:bg-red-50 transition-colors"
              >
                会話履歴をすべて削除
              </button>
            ) : (
              <div className="bg-red-50 border border-red-200 rounded-xl p-4">
                <p className="text-sm text-red-800 mb-3">
                  会話履歴がすべて削除されます。この操作は元に戻せません。
                </p>
                <div className="flex gap-2">
                  <button
                    onClick={handleClearHistory}
                    className="flex-1 py-2 px-4 bg-red-500 text-white rounded-lg font-medium hover:bg-red-600 transition-colors"
                  >
                    削除する
                  </button>
                  <button
                    onClick={() => setShowClearConfirm(false)}
                    className="flex-1 py-2 px-4 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition-colors"
                  >
                    キャンセル
                  </button>
                </div>
              </div>
            )}
          </Section>

          {/* 保存ボタン */}
          <button
            onClick={handleSave}
            className="w-full py-3 px-6 bg-blue-600 text-white font-semibold rounded-xl hover:bg-blue-700 transition-colors"
          >
            {saved ? '✅ 保存しました' : '設定を保存'}
          </button>

          {/* ログアウト */}
          <Section title="🔐 アカウント">
            <button
              onClick={handleLogout}
              disabled={loggingOut}
              className="w-full py-2.5 px-4 rounded-xl border-2 border-gray-300 text-gray-600 font-medium hover:bg-gray-100 transition-colors"
            >
              {loggingOut ? 'ログアウト中...' : 'ログアウト（Face IDセッション終了）'}
            </button>
          </Section>

          <p className="text-xs text-gray-400 text-center mt-2">
            🔒 Claude APIキーはサーバー側で管理。その他の設定はlocalStorageに保存されます
          </p>
        </div>
      </main>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-8">
      <h2 className="text-base font-semibold text-gray-700 mb-4">{title}</h2>
      <div className="space-y-4">{children}</div>
    </div>
  )
}

function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
      {children}
      {hint && <p className="text-xs text-gray-400 mt-1">{hint}</p>}
    </div>
  )
}

function EyeIcon() {
  return (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      <path strokeLinecap="round" strokeLinejoin="round"
        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
    </svg>
  )
}

function EyeOffIcon() {
  return (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round"
        d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
    </svg>
  )
}
