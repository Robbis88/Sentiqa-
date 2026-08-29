'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { skrivAvledteVakter } from '@/lib/stempling/skriv'
import {
  vurderLukking, vurderAnnullering, iNorskTid, FEILTEKST,
} from '@/lib/stempling/rettelse'
import { loggOppslag } from '@/lib/personvern/logg'

export type RettelseSvar = { ok?: true; feil?: string } | undefined

/**
 * Lukker en vakt som mangler utstempling.
 *
 * LEGGER TIL, RETTER IKKE. Innstemplingen står urørt; vi setter inn den
 * manglende ut-hendelsen med `kilde = 'korreksjon'` og `retter_id` mot
 * innstemplingen. Da viser raden i ettertid at et menneske oppga tiden,
 * ikke nettbrettet — som er forskjellen bokføringsloven ber om.
 *
 * Timene skrives om etterpå, slik at lønnsgrunnlaget stemmer med en gang
 * og sperren slipper opp.
 */
export async function lukkVakt(
  _t: RettelseSvar, formData: FormData,
): Promise<RettelseSvar> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return { feil: 'Ikke tilgang.' }

  const innId = String(formData.get('inn_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  const klokke = String(formData.get('klokke') ?? '')
  const begrunnelse = String(formData.get('begrunnelse') ?? '')
  if (!innId) return { feil: 'Ukjent innstempling.' }

  const supabase = await lagSupabaseServerKlient()

  // Henter innstemplingen gjennom RLS: treffer den ingenting, har hun
  // ikke tilgang til stasjonen, og da er «ukjent» riktigere enn «nektet».
  const { data: inn } = await supabase
    .from('stempling_hendelse')
    .select('id, stasjon_id, ansatt_nr, ansatt_navn, tidspunkt, type, annullert_tid')
    .eq('id', innId)
    .maybeSingle<{
      id: string; stasjon_id: string; ansatt_nr: string; ansatt_navn: string
      tidspunkt: string; type: string; annullert_tid: string | null
    }>()
  if (!inn || inn.type !== 'inn' || inn.annullert_tid) {
    return { feil: 'Fant ikke den åpne vakta. Last siden på nytt.' }
  }

  const ut = iNorskTid(dato, klokke)
  const feil = vurderLukking(
    { inn: inn.tidspunkt, ut: ut ?? '', begrunnelse }, new Date())
  if (feil.length > 0) return { feil: feil.map((f) => FEILTEKST[f]).join(' ') }

  const { error } = await supabase.from('stempling_hendelse').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: inn.stasjon_id,
    ansatt_nr: inn.ansatt_nr,
    ansatt_navn: inn.ansatt_navn,
    tidspunkt: ut,
    type: 'ut',
    kilde: 'korreksjon',
    retter_id: inn.id,
    begrunnelse: begrunnelse.trim(),
    registrert_av: bruker.id,
  })
  if (error) {
    return {
      feil: /duplicate|unique/i.test(error.message)
        ? 'Det finnes allerede en utstempling på det tidspunktet.'
        : 'Ble ikke lagret. Prøv igjen.',
    }
  }

  // Noen har rort en annens lonnsgrunnlag. Det skal staa i loggen.
  await loggOppslag(supabase, {
    retailerId: bruker.retailerId,
    stasjonId: inn.stasjon_id,
    handling: 'stempling_rettet',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { ansattNr: inn.ansatt_nr, slag: 'lukket_vakt', begrunnelse: begrunnelse.trim() },
  })

  await skrivAvledteVakter(supabase, inn.stasjon_id, inn.ansatt_nr, new Date(ut!))
  return { ok: true }
}

/**
 * Annullerer en hendelse som ikke skulle vært der.
 *
 * Sletter ikke. Raden blir stående med `annullert_tid`, `annullert_av`
 * og begrunnelsen, og faller ut av avledningen fordi alle spørringene
 * filtrerer på `annullert_tid is null`.
 *
 * Brukes når noen stemplet inn ved en feil — da finnes det ingen vakt å
 * lukke, og å oppgi en utstempling ville lagt inn timer hun ikke jobbet.
 */
export async function annullerHendelse(
  _t: RettelseSvar, formData: FormData,
): Promise<RettelseSvar> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return { feil: 'Ikke tilgang.' }

  const id = String(formData.get('hendelse_id') ?? '')
  const begrunnelse = String(formData.get('begrunnelse') ?? '')
  if (!id) return { feil: 'Ukjent hendelse.' }

  const feil = vurderAnnullering(begrunnelse)
  if (feil.length > 0) return { feil: feil.map((f) => FEILTEKST[f]).join(' ') }

  const supabase = await lagSupabaseServerKlient()
  const { data: h } = await supabase
    .from('stempling_hendelse')
    .select('id, stasjon_id, ansatt_nr, tidspunkt, annullert_tid')
    .eq('id', id)
    .maybeSingle<{
      id: string; stasjon_id: string; ansatt_nr: string
      tidspunkt: string; annullert_tid: string | null
    }>()
  if (!h) return { feil: 'Fant ikke hendelsen. Last siden på nytt.' }
  if (h.annullert_tid) return { ok: true } // Alt annullert. Ikke en feil.

  const { error } = await supabase
    .from('stempling_hendelse')
    .update({
      annullert_tid: new Date().toISOString(),
      annullert_av: bruker.id,
      begrunnelse: begrunnelse.trim(),
    })
    .eq('id', id)
    .is('annullert_tid', null)
  if (error) return { feil: 'Ble ikke lagret. Prøv igjen.' }

  await loggOppslag(supabase, {
    retailerId: bruker.retailerId,
    stasjonId: h.stasjon_id,
    handling: 'stempling_rettet',
    brukerId: bruker.id,
    brukerNavn: bruker.fulltNavn,
    detaljer: { ansattNr: h.ansatt_nr, slag: 'annullert', begrunnelse: begrunnelse.trim() },
  })

  await skrivAvledteVakter(supabase, h.stasjon_id, h.ansatt_nr, new Date(h.tidspunkt))
  return { ok: true }
}
