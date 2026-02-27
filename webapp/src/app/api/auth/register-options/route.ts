import { generateRegistrationOptions } from '@simplewebauthn/server'
import { cookies } from 'next/headers'
import { createChallengeToken, getRpId } from '@/lib/auth'

export const runtime = 'nodejs'

export async function POST(req: Request) {
  // セットアップシークレットを確認
  const { setupSecret } = await req.json()
  if (!setupSecret || setupSecret !== process.env.SETUP_SECRET) {
    return Response.json({ error: 'セットアップパスワードが正しくありません' }, { status: 401 })
  }

  // すでに登録済みならブロック
  if (process.env.WEBAUTHN_CREDENTIAL && process.env.WEBAUTHN_CREDENTIAL.trim() !== '') {
    return Response.json({ error: 'すでに登録済みです。/login からログインしてください' }, { status: 400 })
  }

  const rpID = getRpId()
  const options = await generateRegistrationOptions({
    rpName: 'Claude Code Web',
    rpID,
    userName: 'user',
    userDisplayName: 'ユーザー',
    userID: new TextEncoder().encode('claude-code-web-user'),
    attestationType: 'none',
    authenticatorSelection: {
      authenticatorAttachment: 'platform',
      userVerification: 'required',
      residentKey: 'preferred'
    }
  })

  // チャレンジをcookieに保存（5分間有効）
  const challengeToken = await createChallengeToken(options.challenge)
  const cookieStore = await cookies()
  cookieStore.set('webauthn-challenge', challengeToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 300,
    path: '/'
  })

  return Response.json(options)
}
