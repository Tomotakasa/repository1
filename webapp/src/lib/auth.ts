import { SignJWT, jwtVerify } from 'jose'

const secret = new TextEncoder().encode(
  process.env.AUTH_SECRET ?? 'dev-secret-please-change'
)

export const SESSION_COOKIE = 'session'
export const CHALLENGE_COOKIE = 'webauthn-challenge'

export async function createSessionToken(): Promise<string> {
  return new SignJWT({ authenticated: true })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(secret)
}

export async function verifySessionToken(token: string): Promise<boolean> {
  try {
    await jwtVerify(token, secret)
    return true
  } catch {
    return false
  }
}

export async function createChallengeToken(challenge: string): Promise<string> {
  return new SignJWT({ challenge })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('5m')
    .sign(secret)
}

export async function getChallengeFromToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret)
    return payload.challenge as string
  } catch {
    return null
  }
}

export interface StoredCredential {
  id: string        // base64url
  publicKey: string // base64 (serialized Uint8Array)
  counter: number
  transports?: string[]
}

export function getStoredCredential(): StoredCredential | null {
  const raw = process.env.WEBAUTHN_CREDENTIAL
  if (!raw || raw.trim() === '') return null
  try {
    return JSON.parse(raw) as StoredCredential
  } catch {
    return null
  }
}

export function getRpId(): string {
  return process.env.WEBAUTHN_RP_ID ?? 'localhost'
}

export function getOrigin(): string {
  return process.env.WEBAUTHN_ORIGIN ?? 'http://localhost:3000'
}
