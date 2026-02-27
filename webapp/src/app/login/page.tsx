import { redirect } from 'next/navigation'
import LoginClient from './LoginClient'

export default function LoginPage() {
  // Face IDが未登録ならセットアップへ
  const hasCredential =
    !!process.env.WEBAUTHN_CREDENTIAL && process.env.WEBAUTHN_CREDENTIAL.trim() !== ''
  if (!hasCredential) {
    redirect('/setup')
  }
  return <LoginClient />
}
