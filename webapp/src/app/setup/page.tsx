import { redirect } from 'next/navigation'
import SetupClient from './SetupClient'

export default function SetupPage() {
  const isConfigured =
    !!process.env.ADMIN_PASSWORD && process.env.ADMIN_PASSWORD.trim() !== ''
  if (isConfigured) {
    redirect('/login')
  }
  return <SetupClient />
}
