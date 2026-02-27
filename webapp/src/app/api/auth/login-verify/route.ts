import { verifyAuthenticationResponse } from '@simplewebauthn/server'
import { cookies } from 'next/headers'
import {
  getChallengeFromToken,
  createSessionToken,
  getRpId,
  getOrigin,
  getStoredCredential,
  SESSION_COOKIE
} from '@/lib/auth'

export const runtime = 'nodejs'

export async function POST(req: Request) {
  const cookieStore = await cookies()
  const challengeToken = cookieStore.get('webauthn-challenge')?.value
  if (!challengeToken) {
    return Response.json({ error: 'チャレンジが見つかりません。再度お試しください' }, { status: 400 })
  }

  const expectedChallenge = await getChallengeFromToken(challengeToken)
  if (!expectedChallenge) {
    return Response.json({ error: 'チャレンジが期限切れです。再度お試しください' }, { status: 400 })
  }

  const storedCred = getStoredCredential()
  if (!storedCred) {
    return Response.json({ error: '登録済みの認証情報が見つかりません' }, { status: 404 })
  }

  const response = await req.json()

  let verification
  try {
    verification = await verifyAuthenticationResponse({
      response,
      expectedChallenge,
      expectedOrigin: getOrigin(),
      expectedRPID: getRpId(),
      authenticator: {
        credentialID: storedCred.id,
        credentialPublicKey: Buffer.from(storedCred.publicKey, 'base64'),
        counter: storedCred.counter,
        transports: storedCred.transports as import('@simplewebauthn/types').AuthenticatorTransportFuture[] | undefined
      },
      requireUserVerification: true
    })
  } catch (e) {
    return Response.json({ error: `認証に失敗しました: ${(e as Error).message}` }, { status: 401 })
  }

  if (!verification.verified) {
    return Response.json({ error: '認証情報の検証に失敗しました' }, { status: 401 })
  }

  // チャレンジcookieを削除してセッションcookieを発行
  cookieStore.delete('webauthn-challenge')
  const sessionToken = await createSessionToken()
  cookieStore.set(SESSION_COOKIE, sessionToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 30, // 30日
    path: '/'
  })

  return Response.json({ success: true })
}
