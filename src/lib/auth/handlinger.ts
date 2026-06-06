'use server'
import { redirect } from 'next/navigation'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export async function loggUt() {
  const supabase = await lagSupabaseServerKlient()
  await supabase.auth.signOut()
  redirect('/logg-inn')
}
