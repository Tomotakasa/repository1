import { verifyRegistrationResponse } from '@simplewebauthn/server'
import { cookies } from 'next/headers'
import { getChallengeFromToken, getRpId, getOrigin, StoredCredential } from '@/lib/auth'

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

  const response = await req.json()

  let verification
  try {
    verification = await verifyRegistrationResponse({
      response,
      expectedChallenge,
      expectedOrigin: getOrigin(),
      expectedRPID: getRpId(),
      requireUserVerification: true
    })
  } catch (e) {
    return Response.json({ error: `登録に失敗しました: ${(e as Error).message}` }, { status: 400 })
  }

  if (!verification.verified || !verification.registrationInfo) {
    return Response.json({ error: '認証情報の検証に失敗しました' }, { status: 400 })
  }

  const { credentialID, credentialPublicKey } = verification.registrationInfo
  const storedCredential: StoredCredential = {
    id: credentialID,
    publicKey: Buffer.from(credentialPublicKey).toString('base64'),
    counter: 0, // Face IDはcounterを使わないため0で固定
    transports: response.response.transports ?? []
  }

  // チャレンジcookieを削除
  cookieStore.delete('webauthn-challenge')

  return Response.json({
    success: true,
    credential: JSON.stringify(storedCredential)
  })
}
