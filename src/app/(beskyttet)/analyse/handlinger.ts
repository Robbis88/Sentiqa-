'use server'
import { revalidatePath } from 'next/cache'
import { genererRegnskapsanalyse } from '@/lib/ai/regnskapsanalyse'

export async function generer() {
  const res = await genererRegnskapsanalyse()
  revalidatePath('/analyse')
  return res
}
