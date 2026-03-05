import { cookies } from 'next/headers'
import { createSessionToken, SESSION_COOKIE } from '@/lib/auth'

export const runtime = 'nodejs'

export async function POST(req: Request) {
  const { password } = await req.json()

  if (!password) {
    return Response.json({ error: 'パスワードを入力してください' }, { status: 400 })
  }

  const adminPassword = process.env.ADMIN_PASSWORD
  const guestPassword = process.env.GUEST_PASSWORD

  const isAdmin = adminPassword && password === adminPassword
  const isGuest = guestPassword && password === guestPassword

  if (!isAdmin && !isGuest) {
    return Response.json({ error: 'パスワードが正しくありません' }, { status: 401 })
  }

  const cookieStore = await cookies()
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
