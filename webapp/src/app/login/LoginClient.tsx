'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function LoginClient() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const router = useRouter()

  async function handleFaceID() {
    setLoading(true)
    setError('')
    try {
      const optRes = await fetch('/api/auth/login-options', { method: 'POST' })
      if (!optRes.ok) {
        const d = await optRes.json()
        setError(d.error ?? 'オプション取得に失敗しました')
        return
      }
      const options = await optRes.json()

      const { startAuthentication } = await import('@simplewebauthn/browser')
      const assertion = await startAuthentication(options)

      const verifyRes = await fetch('/api/auth/login-verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(assertion)
      })

      if (verifyRes.ok) {
        router.push('/chat')
        router.refresh()
      } else {
        const d = await verifyRes.json()
        setError(d.error ?? '認証に失敗しました')
      }
    } catch (e) {
      const msg = (e as Error).message ?? ''
      if (msg.includes('cancel') || msg.includes('abort') || msg.includes('NotAllowed')) {
        setError('Face IDの認証がキャンセルされました')
      } else {
        setError(`エラーが発生しました: ${msg}`)
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 to-blue-950">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-sm text-center">
        <div className="w-16 h-16 bg-gradient-to-br from-violet-500 to-blue-500 rounded-2xl flex items-center justify-center text-white text-2xl font-bold mx-auto mb-5">
          AI
        </div>
        <h1 className="text-xl font-bold text-gray-800 mb-1">Claude Code Web</h1>
        <p className="text-gray-400 text-sm mb-8">Face IDでログイン</p>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3 mb-4 text-red-600 text-sm">
            {error}
          </div>
        )}

        <button
          onClick={handleFaceID}
          disabled={loading}
          className="w-full py-3.5 px-6 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-semibold rounded-xl transition-colors flex items-center justify-center gap-2"
        >
          {loading ? (
            <>
              <SpinIcon />
              認証中...
            </>
          ) : (
            <>
              <FaceIDIcon />
              Face IDでログイン
            </>
          )}
        </button>

        <p className="text-xs text-gray-300 mt-6">
          iPhoneのFace IDを使って認証します
        </p>
      </div>
    </div>
  )
}

function FaceIDIcon() {
  return (
    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round"
        d="M7.5 3.75H6A2.25 2.25 0 003.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0120.25 6v1.5m0 9V18A2.25 2.25 0 0118 20.25h-1.5m-9 0H6A2.25 2.25 0 013.75 18v-1.5M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
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
