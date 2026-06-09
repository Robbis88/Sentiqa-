'use server'
import { cookies } from 'next/headers'
import { revalidatePath } from 'next/cache'
import { erGyldigSprak } from '@/lib/sprak'

export async function setSprak(formData: FormData) {
  const kode = String(formData.get('kode') ?? 'no')
  if (!erGyldigSprak(kode)) return
  ;(await cookies()).set('sprak', kode, { path: '/', maxAge: 60 * 60 * 24 * 365, sameSite: 'lax' })
  revalidatePath('/', 'layout')
}
