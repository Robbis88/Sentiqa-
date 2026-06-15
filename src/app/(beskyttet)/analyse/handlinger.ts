'use server'
import { revalidatePath } from 'next/cache'
import { genererRegnskapsanalyse, genererRegnskapsanalyseHittil } from '@/lib/ai/regnskapsanalyse'

export async function generer() {
  const res = await genererRegnskapsanalyse()
  revalidatePath('/analyse')
  return res
}

export async function genererHeleAaret(aar?: string) {
  const res = await genererRegnskapsanalyseHittil(aar)
  revalidatePath('/analyse')
  return res
}
