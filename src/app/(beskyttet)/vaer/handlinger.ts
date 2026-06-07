'use server'
import { revalidatePath } from 'next/cache'
import { hentVaerForAlle } from '@/lib/vaer'

export async function hentVaer() {
  const res = await hentVaerForAlle()
  revalidatePath('/vaer')
  return res
}
