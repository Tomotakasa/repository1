import { redirect } from 'next/navigation'
import SetupClient from './SetupClient'

export default function SetupPage() {
  // すでに登録済みならログインへ
  const hasCredential =
    !!process.env.WEBAUTHN_CREDENTIAL && process.env.WEBAUTHN_CREDENTIAL.trim() !== ''
  if (hasCredential) {
    redirect('/login')
  }
  return <SetupClient />
}
