'use server'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesTimesats } from '@/lib/lonn/timesats'
import { vurderSkiftordning, type Skiftordning } from '@/lib/lonn/tariff'

export type Tilstand = { ok?: string; feil?: string } | undefined

const Sats = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
})

/**
 * Registrerer utbetalt timesats for én ansatt.
 *
 * Satsen brukes ikke til å regne ut lønn — Visma-fila bærer timer, og
 * Azets holder satsene. Den er en KONTROLL: uten den ser ingen at Helene
 * ligger 15,44 under laveste voksensats i Energiavtalen.
 *
 * Derfor kan den også endres fritt, når som helst. Ingenting nedstrøms
 * fryser på den, og en allerede generert kontrakt beholder sitt eget
 * øyeblikksbilde av verdiene uansett.
 */
export async function settTimesats(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }

  const felt = Sats.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const sats = lesTimesats(fd.get('timesats'))
  if (!sats.ok) return { feil: sats.feil }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, timesats: sats.verdi, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  return { ok: 'Lagret' }
}

const Form = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
  lonnsform: z.literal(['timelonn', 'fastlonn', 'tilkalling']),
})

const LangeUker = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
})

/**
 * Krysser av for individuell avtale om lange uker (aml. § 10-5).
 *
 * SETTES AV ET MENNESKE, ALDRI UTLEDET. Avtalen er skriftlig og finnes
 * utenfor systemet; en lang uke i dataene er et symptom paa den, ikke et
 * bevis. Utledet automatisk ville en travel maaned slaatt av varselet
 * for den som trengte det mest.
 */
export async function settLangeUker(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }

  const felt = LangeUker.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  // Avkryssingsbokser sender ingenting naar de er AV. Tilstanden leses
  // derfor av tilstedevaerelsen, ikke av en verdi - og da kan haken tas
  // bort igjen.
  const paa = fd.get('lange_uker') != null

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, lange_uker_avtalt: paa, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  return { ok: paa ? 'Lange uker er avtalt' : 'Haken er tatt bort' }
}

/**
 * Setter lønnsformen for én ansatt.
 *
 * Upsert, ikke update: de fleste som stempler har ikke noe ansattkort fra
 * før — det er nettopp derfor lønnsformen mangler.
 */
export async function settLonnsform(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }

  const felt = Form.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
    lonnsform: fd.get('lonnsform'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  return { ok: 'Lagret' }
}

/**
 * Setter arbeidstid for dem satsen peker entydig på — der feltet står tomt.
 *
 * SATSEN ER ET SPOR, IKKE EN BESLUTNING. Skiftordning er avtalefestet:
 * § 2.7.1.1 krever enighet med tillitsvalgte, skriftlig oppsigelse av
 * gjeldende ordning og skiftplan fire uker i forveien. Feltet påstår at
 * en slik ordning FINNES — ikke at timesatsen er høy.
 *
 * Og det virker tilbake: feltet bestemmer overtidsgrensen. Utledet
 * automatisk ville en feilført timesats avgjort når overtid slår inn, og
 * feilen ville forsterket seg selv i stedet for å bli oppdaget.
 *
 * Derfor er dette en HANDLING lederen utløser, ikke en regel som går av
 * seg selv. Systemet gjør tastingen; beslutningen er hennes.
 *
 * ---------------------------------------------------------------------
 * RØRER ALDRI ET FELT NOEN HAR SATT
 *
 * Bare `ikke_satt`. En MOTSIGELSE — feltet sier ordinær, satsen sier to
 * skift — er nettopp det et menneske må avgjøre: én av dem er feil, og
 * hvilken kan ikke leses ut av tallene. Å overskrive den ville gjort en
 * lønnsføring til fasit over en avtale.
 */
export async function settSkiftFraSats(stasjonId: string): Promise<
  { ok: true; endret: number; hoppet: number } | { ok: false; feil: string }
> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { ok: false, feil: 'Ikke tilgang.' }
  if (!z.string().uuid().safeParse(stasjonId).success) {
    return { ok: false, feil: 'Ukjent stasjon.' }
  }

  const supabase = await lagSupabaseServerKlient()
  const { data, error } = await supabase
    .from('ansatt_avtale')
    .select('ansatt_nr, navn, timesats, skiftordning')
    .eq('stasjon_id', stasjonId)
  if (error) return { ok: false, feil: error.message }

  const rader = (data ?? []) as {
    ansatt_nr: string; navn: string | null
    timesats: number | null; skiftordning: Skiftordning | null
  }[]

  const skal: { ansatt_nr: string; navn: string; ordning: Skiftordning }[] = []
  let hoppet = 0
  for (const r of rader) {
    if (r.timesats == null) continue
    const v = vurderSkiftordning(Number(r.timesats), r.skiftordning ?? null)
    if (!v) continue
    if (v.slag === 'motsier') { hoppet++; continue }
    skal.push({ ansatt_nr: r.ansatt_nr, navn: r.navn ?? r.ansatt_nr, ordning: v.antydet })
  }

  if (skal.length === 0) return { ok: true, endret: 0, hoppet }

  const naa = new Date().toISOString()
  const { error: se } = await supabase.from('ansatt_avtale').upsert(
    skal.map((x) => ({
      stasjon_id: stasjonId, ansatt_nr: x.ansatt_nr, navn: x.navn,
      skiftordning: x.ordning, oppdatert_tid: naa,
    })),
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (se) return { ok: false, feil: se.message }
  return { ok: true, endret: skal.length, hoppet }
}
