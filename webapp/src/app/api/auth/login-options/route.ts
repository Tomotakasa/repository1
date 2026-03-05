import { generateAuthenticationOptions } from '@simplewebauthn/server'
import { cookies } from 'next/headers'
import { createChallengeToken, getRpId, getStoredCredential } from '@/lib/auth'

export const runtime = 'nodejs'

export async function POST() {
  const credential = getStoredCredential()
  if (!credential) {
    return Response.json(
      { error: 'Face IDが未登録です。まず /setup でセットアップしてください' },
      { status: 404 }
    )
  }

  const options = await generateAuthenticationOptions({
    rpID: getRpId(),
    allowCredentials: [{ id: credential.id }],
    userVerification: 'required'
  })

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
