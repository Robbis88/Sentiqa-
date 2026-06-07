'use server'
import { revalidatePath } from 'next/cache'
import { genererAlleFokus } from '@/lib/ai/fokus'

export async function generer() {
  const res = await genererAlleFokus()
  revalidatePath('/fokus')
  return res
}
