'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { opprettVarsel } from '@/lib/varsler'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { STANDARD_KONTROLLPUNKTER } from '@/lib/ikmat/standard'

function iDag(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
}

// Tablet/ansatt logger en temperatur. Utenfor kravet → avvik + varsel (§16.5).
export async function registrerAvlesning(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const punktId = String(formData.get('kontrollpunkt_id') ?? '')
  const raw = String(formData.get('temperatur') ?? '').replace(',', '.').trim()
  const tiltak = String(formData.get('tiltak') ?? '').trim() || null
  const temp = Number(raw)
  if (!punktId || raw === '' || !Number.isFinite(temp)) return

  const supabase = await lagSupabaseServerKlient()
  const { data: punkt } = await supabase
    .from('ik_kontrollpunkter')
    .select('navn, stasjon_id, min_temp, max_temp')
    .eq('id', punktId)
    .maybeSingle<{ navn: string; stasjon_id: string; min_temp: number | null; max_temp: number | null }>()
  if (!punkt) return

  const underMin = punkt.min_temp != null && temp < punkt.min_temp
  const overMax = punkt.max_temp != null && temp > punkt.max_temp
  const innenfor = !underMin && !overMax
  const ansatt = await lesAktivAnsatt()

  await supabase.from('ik_avlesninger').insert({
    kontrollpunkt_id: punktId,
    stasjon_id: punkt.stasjon_id,
    dato: iDag(),
    temperatur: temp,
    innenfor,
    tiltak,
    avlest_av: bruker.id,
    ansatt_id: ansatt?.id ?? null,
  })

  if (!innenfor && bruker.retailerId) {
    const krav = punkt.max_temp != null ? `maks ${punkt.max_temp}°C` : `min +${punkt.min_temp}°C`
    await opprettVarsel(supabase, {
      retailer_id: bruker.retailerId,
      stasjon_id: punkt.stasjon_id,
      type: 'ikmat',
      tittel: `IK-mat avvik: ${punkt.navn}`,
      tekst: `Målt ${temp}°C (krav ${krav}).${tiltak ? ` Tiltak: ${tiltak}` : ' Husk å registrere avvik (S01).'}`,
      lenke: '/avvik',
    })
  }
  revalidatePath('/ikmat')
}

// Setter opp hele St1-standarden for en stasjon med ett klikk.
export async function settOppStandard(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  if (!stasjonId || !bruker.retailerId) return

  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase
    .from('ik_kontrollpunkter')
    .select('*', { count: 'exact', head: true })
    .eq('stasjon_id', stasjonId)
    .is('slettet_tid', null)
  if ((count ?? 0) > 0) return // ikke dobbel-seed

  const rader = STANDARD_KONTROLLPUNKTER.map((p, i) => ({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    navn: p.navn,
    type: p.type,
    min_temp: p.min_temp,
    max_temp: p.max_temp,
    frekvens: p.frekvens,
    sortering: i,
    opprettet_av: bruker.id,
  }))
  await supabase.from('ik_kontrollpunkter').insert(rader)
  revalidatePath('/ikmat')
}

export async function leggTilPunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const navn = String(formData.get('navn') ?? '').trim()
  const type = String(formData.get('type') ?? 'kjol')
  const frekvens = String(formData.get('frekvens') ?? 'daglig')
  const num = (felt: string) => {
    const v = String(formData.get(felt) ?? '').replace(',', '.').trim()
    return v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null
  }
  if (!stasjonId || !navn) return

  const supabase = await lagSupabaseServerKlient()
  await supabase.from('ik_kontrollpunkter').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    navn,
    type,
    frekvens,
    min_temp: num('min_temp'),
    max_temp: num('max_temp'),
    sortering: 999,
    opprettet_av: bruker.id,
  })
  revalidatePath('/ikmat')
}
