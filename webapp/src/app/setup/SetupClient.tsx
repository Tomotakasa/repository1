'use client'

import { useState } from 'react'

type Step = 'password' | 'register' | 'done'

export default function SetupClient() {
  const [step, setStep] = useState<Step>('password')
  const [setupSecret, setSetupSecret] = useState('')
  const [credentialJson, setCredentialJson] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [copied, setCopied] = useState(false)

  async function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!setupSecret.trim()) return
    setStep('register')
    setError('')
  }

  async function handleRegister() {
    setLoading(true)
    setError('')
    try {
      const optRes = await fetch('/api/auth/register-options', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ setupSecret })
      })
      if (!optRes.ok) {
        const d = await optRes.json()
        setError(d.error ?? 'オプション取得に失敗しました')
        return
      }
      const options = await optRes.json()

      const { startRegistration } = await import('@simplewebauthn/browser')
      const regResponse = await startRegistration(options)

      const verifyRes = await fetch('/api/auth/register-verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(regResponse)
      })

      if (verifyRes.ok) {
        const data = await verifyRes.json()
        setCredentialJson(data.credential)
        setStep('done')
      } else {
        const d = await verifyRes.json()
        setError(d.error ?? '登録に失敗しました')
      }
    } catch (e) {
      const msg = (e as Error).message ?? ''
      setError(`エラー: ${msg}`)
    } finally {
      setLoading(false)
    }
  }

  async function handleCopy() {
    await navigator.clipboard.writeText(credentialJson)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 to-blue-950 p-4">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md">
        <div className="w-12 h-12 bg-gradient-to-br from-violet-500 to-blue-500 rounded-xl flex items-center justify-center text-white font-bold mx-auto mb-5">
          AI
        </div>
        <h1 className="text-xl font-bold text-gray-800 text-center mb-1">初回セットアップ</h1>
        <p className="text-gray-400 text-sm text-center mb-6">Face IDを登録してアプリを保護します</p>

        {/* Step 1: パスワード確認 */}
        {step === 'password' && (
          <form onSubmit={handlePasswordSubmit} className="space-y-4">
            <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 text-sm text-blue-800">
              <p className="font-semibold mb-1">セットアップパスワードを入力</p>
              <p>環境変数 <code className="bg-blue-100 px-1 rounded">SETUP_SECRET</code> に設定した値を入力してください</p>
            </div>
            <input
              type="password"
              value={setupSecret}
              onChange={e => setSetupSecret(e.target.value)}
              placeholder="セットアップパスワード"
              className="w-full rounded-xl border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
              autoFocus
            />
            <button
              type="submit"
              disabled={!setupSecret.trim()}
              className="w-full py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-200 text-white font-semibold rounded-xl transition-colors"
            >
              次へ
            </button>
          </form>
        )}

        {/* Step 2: Face ID 登録 */}
        {step === 'register' && (
          <div className="space-y-4">
            <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-sm text-green-800">
              <p className="font-semibold mb-1">Face IDを登録します</p>
              <p>ボタンを押すとFace IDの登録画面が表示されます。iPhoneで顔認証してください。</p>
            </div>
            {error && (
              <div className="bg-red-50 border border-red-200 rounded-xl p-3 text-red-600 text-sm">
                {error}
              </div>
            )}
            <button
              onClick={handleRegister}
              disabled={loading}
              className="w-full py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 text-white font-semibold rounded-xl transition-colors flex items-center justify-center gap-2"
            >
              {loading ? '登録中...' : 'Face IDを登録する'}
            </button>
          </div>
        )}

        {/* Step 3: 完了 → 認証情報をコピー */}
        {step === 'done' && (
          <div className="space-y-4">
            <div className="bg-green-50 border border-green-200 rounded-xl p-4 text-sm text-green-800">
              <p className="font-semibold mb-1">✅ Face IDの登録完了！</p>
              <p>以下の手順で設定を完了してください。</p>
            </div>

            <div className="space-y-3 text-sm text-gray-700">
              <p className="font-semibold">次のステップ:</p>
              <ol className="list-decimal list-inside space-y-2 text-gray-600">
                <li>下の認証情報をコピーする</li>
                <li>Vercel Dashboard → Settings → Environment Variables を開く</li>
                <li><code className="bg-gray-100 px-1 rounded text-xs">WEBAUTHN_CREDENTIAL</code> に貼り付ける</li>
                <li>Vercelを再デプロイする</li>
                <li>再デプロイ後、/login からFace IDでログインできます</li>
              </ol>
            </div>

            <div>
              <p className="text-xs text-gray-500 mb-2 font-medium">認証情報（WEBAUTHN_CREDENTIAL の値）:</p>
              <div className="bg-gray-900 rounded-xl p-3 overflow-x-auto">
                <code className="text-xs text-green-400 break-all">{credentialJson}</code>
              </div>
              <button
                onClick={handleCopy}
                className="mt-2 w-full py-2.5 bg-gray-800 hover:bg-gray-700 text-white text-sm font-medium rounded-xl transition-colors"
              >
                {copied ? '✅ コピーしました' : 'クリップボードにコピー'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
