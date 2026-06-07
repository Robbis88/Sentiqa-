'use server'
import { revalidatePath } from 'next/cache'
import { genererAlleLederstotte } from '@/lib/ai/lederstotte'

export async function generer() {
  const res = await genererAlleLederstotte()
  revalidatePath('/lederstotte')
  return res
}
