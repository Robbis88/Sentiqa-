'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { iDag } from '@/lib/format'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { opprettVarsel } from '@/lib/varsler'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { STANDARD_KONTROLLPUNKTER, kravTekst } from '@/lib/ikmat/standard'

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
  const ansatt = await lesAktivAnsatt(supabase)

  const { error: avlesningFeil } = await supabase.from('ik_avlesninger').insert({
    kontrollpunkt_id: punktId,
    stasjon_id: punkt.stasjon_id,
    dato: iDag(),
    temperatur: temp,
    innenfor,
    tiltak,
    avlest_av: bruker.id,
    ansatt_id: ansatt?.id ?? null,
  })
  if (avlesningFeil) return

  if (!innenfor && bruker.retailerId) {
    const krav = punkt.max_temp != null ? `maks ${punkt.max_temp}°C` : `min +${punkt.min_temp}°C`
    await opprettVarsel(supabase, {
      retailer_id: bruker.retailerId,
      stasjon_id: punkt.stasjon_id,
      type: 'ikmat',
      tittel: `IK-mat avvik: ${punkt.navn}`,
      tekst: `Målt ${temp}°C (krav ${krav}).${tiltak ? ` Tiltak: ${tiltak}` : ' Husk å registrere avvik (S01).'}`,
      lenke: '/ikmat',
    })
  }
  revalidatePath('/ikmat')
}

// Tablet-måling: logg temperatur, og ved avvik (utenfor krav) opprett et ekte
// avvik med strakstiltak der og da. Returnerer resultat så klienten kan reagere.
export type MaalingResultat = { ok?: true; innenfor?: boolean; feil?: string }
export async function loggMaaling(punktId: string, tempStr: string, strakstiltak: string): Promise<MaalingResultat> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }
  const temp = Number(String(tempStr ?? '').replace(',', '.').trim())
  if (!punktId || !Number.isFinite(temp)) return { feil: 'Skriv en temperatur.' }

  const supabase = await lagSupabaseServerKlient()
  const { data: punkt } = await supabase
    .from('ik_kontrollpunkter').select('navn, stasjon_id, min_temp, max_temp')
    .eq('id', punktId).maybeSingle<{ navn: string; stasjon_id: string; min_temp: number | null; max_temp: number | null }>()
  if (!punkt) return { feil: 'Fant ikke kontrollpunktet.' }

  const innenfor = !(punkt.min_temp != null && temp < punkt.min_temp) && !(punkt.max_temp != null && temp > punkt.max_temp)
  const tiltak = String(strakstiltak ?? '').trim()
  if (!innenfor && !tiltak) return { innenfor: false, feil: 'Skriv strakstiltak for avviket.' }

  const ansatt = await lesAktivAnsatt(supabase)
  const { error: avlesningFeil } = await supabase.from('ik_avlesninger').insert({
    kontrollpunkt_id: punktId, stasjon_id: punkt.stasjon_id, dato: iDag(),
    temperatur: temp, innenfor, tiltak: innenfor ? null : tiltak, avlest_av: bruker.id, ansatt_id: ansatt?.id ?? null,
  })
  if (avlesningFeil) return { feil: 'Kunne ikke lagre målingen. Prøv igjen.' }

  if (!innenfor) {
    // Ekte avvik (HACCP) + varsel til leder. Løpenr tildeles av basen (mig 0079)
    // — en count() her ville gått gjennom RLS og gitt kolliderende numre.
    const { error: avvikFeil } = await supabase.from('avvik').insert({
      retailer_id: bruker.retailerId, stasjon_id: punkt.stasjon_id,
      kategori: 'utstyr', dato: iDag(),
      beskrivelse: `IK-mat: ${punkt.navn} målt ${temp}°C (krav ${kravTekst(punkt.min_temp, punkt.max_temp)}).`,
      strakstiltak: tiltak, opprettet_av: bruker.id,
    })
    // Målingen er lagret, men avviket mangler — det skal ikke se ut som alt gikk bra.
    if (avvikFeil) return { innenfor: false, feil: 'Målingen er lagret, men avviket ble ikke registrert. Meld fra til leder.' }
    await opprettVarsel(supabase, {
      retailer_id: bruker.retailerId, stasjon_id: punkt.stasjon_id, type: 'ikmat',
      tittel: `IK-mat avvik: ${punkt.navn}`,
      tekst: `Målt ${temp}°C (krav ${kravTekst(punkt.min_temp, punkt.max_temp)}). Strakstiltak: ${tiltak}`,
      lenke: '/avvik',
    })
  }
  revalidatePath('/ikmat')
  revalidatePath('/rutiner')
  return { ok: true, innenfor }
}

// Setter opp hele St1-standarden for en stasjon med ett klikk.
export async function settOppStandard(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
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
  revalidatePath('/ikmat/oppsett')
}

export async function slettKontrollpunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('ik_kontrollpunkter').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/ikmat')
  revalidatePath('/ikmat/oppsett')
}

function tilTall(formData: FormData, felt: string): number | null {
  const v = String(formData.get(felt) ?? '').replace(',', '.').trim()
  return v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null
}

// Full redigering av et kontrollpunkt (navn, type, frekvens, krav).
export async function oppdaterPunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const navn = String(formData.get('navn') ?? '').trim()
  if (!id || !navn) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('ik_kontrollpunkter').update({
    navn,
    type: String(formData.get('type') ?? 'kjol'),
    frekvens: String(formData.get('frekvens') ?? 'daglig'),
    min_temp: tilTall(formData, 'min_temp'),
    max_temp: tilTall(formData, 'max_temp'),
  }).eq('id', id)
  revalidatePath('/ikmat/oppsett')
  revalidatePath('/ikmat')
}

export async function leggTilPunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const navn = String(formData.get('navn') ?? '').trim()
  const type = String(formData.get('type') ?? 'kjol')
  const frekvens = String(formData.get('frekvens') ?? 'daglig')
  if (!stasjonId || !navn) return

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase.from('ik_kontrollpunkter').select('sortering').eq('stasjon_id', stasjonId).is('slettet_tid', null).order('sortering', { ascending: false }).limit(1).maybeSingle<{ sortering: number | null }>()
  await supabase.from('ik_kontrollpunkter').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    navn,
    type,
    frekvens,
    min_temp: tilTall(formData, 'min_temp'),
    max_temp: tilTall(formData, 'max_temp'),
    sortering: (siste?.sortering ?? -1) + 1,
    opprettet_av: bruker.id,
  })
  revalidatePath('/ikmat/oppsett')
  revalidatePath('/ikmat')
}

// Drag-and-drop rekkefølge: sortering = posisjon i lista (per stasjon).
export async function lagrePunktRekkefolge(stasjonId: string, ids: string[]): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !stasjonId || !Array.isArray(ids)) return
  const supabase = await lagSupabaseServerKlient()
  await Promise.all(ids.map((id, i) => supabase.from('ik_kontrollpunkter').update({ sortering: i }).eq('id', id).eq('stasjon_id', stasjonId)))
  revalidatePath('/ikmat/oppsett')
  revalidatePath('/ikmat')
}
