'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function LoginClient() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [password, setPassword] = useState('')
  const router = useRouter()

  async function handlePasswordLogin(e: React.FormEvent) {
    e.preventDefault()
    if (!password.trim()) return
    setLoading(true)
    setError('')
    try {
      const res = await fetch('/api/auth/password-login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password })
      })
      if (res.ok) {
        router.push('/chat')
        router.refresh()
      } else {
        const d = await res.json()
        setError(d.error ?? 'ログインに失敗しました')
      }
    } catch {
      setError('ネットワークエラーが発生しました')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 to-blue-950">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-sm">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-gradient-to-br from-violet-500 to-blue-500 rounded-2xl flex items-center justify-center text-white text-2xl font-bold mx-auto mb-5">
            AI
          </div>
          <h1 className="text-xl font-bold text-gray-800 mb-1">Claude Code Web</h1>
          <p className="text-gray-400 text-sm">ログイン</p>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3 mb-4 text-red-600 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handlePasswordLogin} className="space-y-3">
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            placeholder="パスワードを入力"
            disabled={loading}
            className="w-full rounded-xl border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 disabled:bg-gray-50"
            autoComplete="current-password"
            autoFocus
          />
          <button
            type="submit"
            disabled={!password.trim() || loading}
            className="w-full py-3.5 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-200 disabled:cursor-not-allowed text-white font-semibold rounded-xl transition-colors flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <SpinIcon />
                ログイン中...
              </>
            ) : (
              'ログイン'
            )}
          </button>
        </form>

        <p className="text-xs text-gray-300 mt-6 text-center">
          アクセスには管理者からの許可が必要です
        </p>
      </div>
    </div>
  )
}

function SpinIcon() {
  return (
    <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  )
}
