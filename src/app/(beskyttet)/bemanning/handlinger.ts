'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

// RLS gjør den egentlige jobben — stasjonstilgang og rolle håndheves i
// policyene fra 0081. Sjekkene her gir bare et vennligere svar enn en
// tom skriveoperasjon.

// Feltene sender "HH:MM" fra <input type="time">. Motoren regner i hele
// timer, saa halvtimer avvises med en setning som sier hva som gjelder -
// ikke en avrunding i stillhet.
const Tid = z.union([
  z.coerce.number().int().min(0).max(24),
  z.string().regex(/^\d{2}:\d{2}$/).transform((v, ctx) => {
    const [t, m] = v.split(':').map(Number)
    if (m !== 0) {
      ctx.addIssue({ code: 'custom', message: 'Bemanningsplanen regner i hele timer — velg et helt klokkeslett.' })
      return z.NEVER
    }
    return t
  }),
])

// <input type="time"> kan ikke uttrykke 24:00 — et vindu som stenger ved
// midnatt sender "00:00". Uten dette ville Bønes (06–24) blitt avvist med
// «Til-tid må være etter fra-tid».
const midnattEr24 = <T extends { fra_time: number; til_time: number }>(v: T): T =>
  (v.til_time === 0 && v.fra_time > 0 ? { ...v, til_time: 24 } : v)
const Ukedag = z.coerce.number().int().min(1).max(7)

const Vindu = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  ukedager: z.array(Ukedag).min(1, { error: 'Velg minst én ukedag.' }),
  fra_time: Tid,
  til_time: Tid,
  min_bemanning: z.coerce.number().int().min(0).max(20),
  gjelder_fra: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { error: 'Ugyldig dato.' }),
}).transform(midnattEr24).refine((v) => v.til_time > v.fra_time, { error: 'Til-tid må være etter fra-tid.' })

const FastVakt = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  navn: z.string().min(1, { error: 'Skriv hvem vakten gjelder.' }),
  ukedager: z.array(Ukedag).min(1, { error: 'Velg minst én ukedag.' }),
  fra_time: Tid,
  til_time: Tid,
  // Mangler feltet (eldre skjema i en aapen fane), er fastlonn det trygge
  // svaret: da teller vakten som dekning uten aa endre en ramme noen alt
  // har planlagt etter.
  timelonnet: z.literal(['fast', 'time']).default('fast').transform((v) => v === 'time'),
}).transform(midnattEr24).refine((v) => v.til_time > v.fra_time, { error: 'Til-tid må være etter fra-tid.' })

const Krav = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  ukedager: z.array(Ukedag).min(1, { error: 'Velg minst én ukedag.' }),
  fra_time: Tid,
  til_time: Tid,
  antall: z.coerce.number().int().min(2).max(20),
  begrunnelse: z.string().optional(),
}).transform(midnattEr24).refine((v) => v.til_time > v.fra_time, { error: 'Til-tid må være etter fra-tid.' })

// ok baerer en tekst: "Lagret." alene sa ingenting om HVA som ble lagret,
// og da et skjema for flere dager bare lagret en av dem, var meldingen den
// eneste tilbakemeldingen - og den loy.
export type Tilstand = { ok?: string; feil?: string } | undefined

async function klient() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return null
  return await lagSupabaseServerKlient()
}

const ukedagerFra = (fd: FormData) => fd.getAll('ukedag').map((u) => Number(u))

export async function lagreVindu(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Vindu.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ukedager: ukedagerFra(fd),
    fra_time: fd.get('fra_time'),
    til_time: fd.get('til_time'),
    min_bemanning: fd.get('min_bemanning'),
    gjelder_fra: fd.get('gjelder_fra'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  // En rad per ukedag — samme utrulling som faste vakter og krav-vinduer.
  const { stasjon_id, fra_time, til_time, min_bemanning, gjelder_fra } = felt.data
  const { error } = await supabase.from('bemanning_vindu').upsert(
    felt.data.ukedager.map((ukedag) => ({
      stasjon_id, ukedag, fra_time, til_time, min_bemanning, gjelder_fra,
      oppdatert_tid: new Date().toISOString(),
    })),
    { onConflict: 'stasjon_id,ukedag,gjelder_fra' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return { ok: `Lagret for ${felt.data.ukedager.length} ${felt.data.ukedager.length === 1 ? 'dag' : 'dager'}` }
}

/**
 * Dagen faste vakter fra for perioder fantes har alltid gjeldt fra.
 *
 * IKKE `now()`. Setter vi dagens dato som standard, ville alle maaneder
 * for i dag plutselig staatt uten faste vakter - og timeregnskapet
 * ville gitt hver stasjon 141 timer i maaneden for hele aaret.
 */
const FOR_ALLTID = '2020-01-01'

/** ISO-dato eller ingenting. Et halvt datofelt er ikke en dato. */
function gyldigDato(v: FormDataEntryValue | null): string | null {
  const s = String(v ?? '').trim()
  return /^d{4}-d{2}-d{2}$/.test(s) ? s : null
}

export async function leggTilFastVakt(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = FastVakt.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    navn: fd.get('navn'),
    ukedager: ukedagerFra(fd),
    fra_time: fd.get('fra_time'),
    til_time: fd.get('til_time'),
    timelonnet: fd.get('lonnsform') ?? undefined,
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { stasjon_id, navn, fra_time, til_time, timelonnet } = felt.data
  const fra = gyldigDato(fd.get('gjelder_fra')) ?? FOR_ALLTID

  // PERIODEN FØR LUKKES FØRST, og det er ikke en detalj.
  //
  // To gyldige rader for samme vakt samtidig ville dobbelttelt
  // dekningen i planleggeren — «butikksjef mandag» ville dekket
  // mandagen to ganger, og gulvet sett bemannet uten at noen sto der.
  //
  // En `exclude`-skranke ville fanget det i basen, men krever btree_gist
  // og gir en feilmelding ingen kan handle på. Her lukkes den forrige i
  // stedet, og `bemanning.test.ts` feller hvis dette forsvinner.
  const dagenFor = new Date(`${fra}T00:00:00Z`)
  dagenFor.setUTCDate(dagenFor.getUTCDate() - 1)
  const { error: lukkFeil } = await supabase.from('bemanning_fast_vakt')
    .update({ gjelder_til: dagenFor.toISOString().slice(0, 10) })
    .eq('stasjon_id', stasjon_id).eq('navn', navn)
    .in('ukedag', felt.data.ukedager)
    .lt('gjelder_fra', fra)
    .is('gjelder_til', null)
  if (lukkFeil) return { feil: `Kunne ikke lukke forrige periode: ${lukkFeil.message}` }

  // Én rad per ukedag — «butikksjef 07–15 man–fre» blir fem rader.
  const { error } = await supabase.from('bemanning_fast_vakt').upsert(
    felt.data.ukedager.map((ukedag) => ({
      stasjon_id, navn, ukedag, fra_time, til_time, timelonnet,
      gjelder_fra: fra,
      gjelder_til: null,
      oppdatert_tid: new Date().toISOString(),
    })),
    { onConflict: 'stasjon_id,navn,ukedag,gjelder_fra' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  revalidatePath('/timeregnskap')
  return { ok: `Lagt til på ${felt.data.ukedager.length} ${felt.data.ukedager.length === 1 ? 'dag' : 'dager'}` }
}

export async function leggTilKrav(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Krav.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ukedager: ukedagerFra(fd),
    fra_time: fd.get('fra_time'),
    til_time: fd.get('til_time'),
    antall: fd.get('antall'),
    begrunnelse: fd.get('begrunnelse'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { stasjon_id, fra_time, til_time, antall, begrunnelse } = felt.data
  const { error } = await supabase.from('bemanning_krav').insert(
    felt.data.ukedager.map((ukedag) => ({
      stasjon_id, ukedag, fra_time, til_time, antall,
      begrunnelse: begrunnelse || null,
    })),
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return { ok: `Lagt til på ${felt.data.ukedager.length} ${felt.data.ukedager.length === 1 ? 'dag' : 'dager'}` }
}

// Tomt felt = intet tak. Det er et gyldig svar, ikke en glemt utfylling,
// saa det lagres som null i stedet for aa avvises.
const Tak = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  maks_bemanning: z.union([
    z.literal('').transform(() => null),
    z.coerce.number().int().min(1).max(20),
  ]),
})

export async function lagreTak(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Tak.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    maks_bemanning: fd.get('maks_bemanning') ?? '',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { error } = await supabase.from('bemanning_stasjon').upsert(
    { ...felt.data, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return {
    ok: felt.data.maks_bemanning === null
      ? 'Taket er fjernet'
      : `Maks ${felt.data.maks_bemanning} i timen`,
  }
}

// Tomt felt = «ikke bestemt», og da skal anslaget fra historikken gjelde.
// Et lagret tall betyr at et menneske har sagt at dette er riktig, og det
// skal aldri overskrives av en ny beregning.
const Stilling = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
  stillingsprosent: z.union([
    z.literal('').transform(() => null),
    z.coerce.number().int().min(1).max(150),
  ]),
})

export async function lagreStilling(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Stilling.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
    stillingsprosent: fd.get('stillingsprosent') ?? '',
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  return {
    ok: felt.data.stillingsprosent === null
      ? 'Tilbake til anslaget'
      : `${felt.data.navn}: ${felt.data.stillingsprosent} %`,
  }
}

const Fravaer = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  navn: z.string().min(1, { error: 'Velg hvem det gjelder.' }),
  fra_dato: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { error: 'Ugyldig fra-dato.' }),
  til_dato: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { error: 'Ugyldig til-dato.' }),
  arsak: z.string().optional(),
}).refine((v) => v.til_dato >= v.fra_dato, { error: 'Til-dato kan ikke være før fra-dato.' })

export async function leggTilFravaer(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const supabase = await klient()
  if (!supabase) return { feil: 'Ikke tilgang.' }
  const felt = Fravaer.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    navn: fd.get('navn'),
    fra_dato: fd.get('fra_dato'),
    til_dato: fd.get('til_dato'),
    arsak: fd.get('arsak'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const { error } = await supabase.from('bemanning_fravaer').insert({
    ...felt.data, arsak: felt.data.arsak || null,
  })
  if (error) return { feil: error.message }
  revalidatePath('/bemanning')
  // Antall dager sier hvor mye det faktisk flytter — «Lagret» sier ingenting.
  const dager = Math.round(
    (Date.parse(felt.data.til_dato) - Date.parse(felt.data.fra_dato)) / 86400000) + 1
  return { ok: `${felt.data.navn} borte i ${dager} ${dager === 1 ? 'dag' : 'dager'}` }
}

async function slett(tabell: string, fd: FormData) {
  const supabase = await klient()
  if (!supabase) return
  const id = String(fd.get('id') ?? '')
  if (!id) return
  await supabase.from(tabell).delete().eq('id', id)
  revalidatePath('/bemanning')
}

export async function slettFastVakt(fd: FormData) { await slett('bemanning_fast_vakt', fd) }
export async function slettKrav(fd: FormData) { await slett('bemanning_krav', fd) }
export async function slettVindu(fd: FormData) { await slett('bemanning_vindu', fd) }
export async function slettFravaer(fd: FormData) { await slett('bemanning_fravaer', fd) }
