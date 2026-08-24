import Link from 'next/link'
import { TabletHode } from '../tablet-hode'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { oversettMange } from '@/lib/oversett'
import { leggTilAnvisning } from './handlinger'
import { OpplastSkjema } from './opplast-skjema'
import { AnvisningListe, type Rad as Kortrad } from './anvisning-liste'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'
import { Knapp } from '@/components/ui/knapp'
import { Felt } from '@/components/ui/felt'

// SIGNERTE URL-ER MED 24 TIMERS LEVETID, aldri offentlige lenker.
//
// LEVETIDEN MÅ VÆRE LENGER ENN CACHE-VINDUET. Er sida cachet lenger enn
// URL-en lever, får brukeren 403 på en lenke som så gyldig ut — og det
// er umulig å feilsøke fra hennes side, for lenken virket i går. Derfor
// `force-dynamic` her, og aldri en kortere levetid enn cachen.
const TTL = 60 * 60 * 24

export const dynamic = 'force-dynamic'

type Rad = {
  id: string
  kategori: string
  tittel: string
  innhold: string | null
  stikkord: string[] | null
  fil_sti: string | null
  dato: string | null
  erstatter_dato: string | null
}

export default async function AnvisningerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('anvisninger')
    .select('id, kategori, tittel, innhold, stikkord, fil_sti, dato, erstatter_dato')
    .is('slettet_tid', null)
    .order('kategori')
    .order('sortering')
    .overrideTypes<Rad[]>()

  const rader = data ?? []

  // BATCHET, OG DET ER DEN VIKTIGSTE YTELSESDETALJEN I HELE MODULEN.
  // `createSignedUrl` i en løkke er ett nettverkskall per ark — 60
  // anvisninger blir 60 rundturer, og forskjellen er sekunder på en
  // tablet over butikk-wifi. Flertallsvarianten tar hele lista i ett.
  const stier = rader.map((r) => r.fil_sti).filter((s): s is string => Boolean(s))
  const url = new Map<string, string>()
  if (stier.length > 0) {
    const { data: signerte } = await supabase.storage
      .from('anvisninger')
      .createSignedUrls(stier, TTL)
    for (const s of signerte ?? []) {
      if (s.path && s.signedUrl) url.set(s.path, s.signedUrl)
    }
  }

  // Oversettelse gjelder KUN tableten. Admin/butikksjef ser alltid norsk
  // (selv om språk-cookien er satt av en tablet-bruker i samme nettleser).
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet'
    ? ((await cookies()).get('sprak')?.value ?? 'no')
    : 'no'
  const fast = [
    'Anvisninger', 'Prosedyrer og oppskrifter — slå opp når du trenger det.',
    'Ingen anvisninger ennå.', 'anvisning', 'anvisninger',
    // Søket. Oversettes her fordi klientkomponenten ikke oversetter.
    'Søk på ingrediens, tittel eller kategori', 'Ingen treff på', 'Søk i anvisningene',
    // Nettbrettets «Hjelp» og foten under den (bølge 5).
    'Hjelp', 'Slå opp når du trenger det.', 'Mer hjelp',
    'Lenker', 'Hurtiglenker for å hjelpe kunder',
    'Nyheter', 'Oppdateringer og tips',
    'Slik måler vi', 'Hva systemet lagrer om deg',
  ]
  const oversatt = await oversettMange(
    [...fast, ...rader.flatMap((a) => [a.kategori, a.tittel, a.innhold ?? ''])],
    sprak,
  )
  const o = (s: string) => oversatt.get(s) ?? s

  const kort: Kortrad[] = rader.map((r) => ({
    id: r.id,
    tittel: r.tittel,
    kategori: r.kategori,
    stikkord: r.stikkord ?? [],
    innhold: r.innhold,
    fil_sti: r.fil_sti,
    dato: r.dato,
    erstatter_dato: r.erstatter_dato,
    url: r.fil_sti ? (url.get(r.fil_sti) ?? null) : null,
    vist: {
      tittel: o(r.tittel),
      kategori: o(r.kategori),
      innhold: r.innhold ? o(r.innhold) : null,
    },
  }))

  const nyPanel = erLeder ? (
    <Sidepanel knapp="Ny anvisning" tittel="Ny anvisning">
      {/* TO SKJEMAER, FORDI DET ER TO ÆRENDER. Et ark fra leverandøren
          lastes opp; en prosedyre dere skriver selv, skrives inn. Ett
          skjema som prøvde å være begge ville tvunget brukeren til å
          gjette hvilke felter som gjaldt henne. */}
      <h3>Last opp et ark (PDF)</h3>
      <OpplastSkjema />

      <form action={leggTilAnvisning} className="sq-skjema">
        <h3>Eller skriv den inn</h3>
        <Felt etikett="Kategori" name="kategori" placeholder="Hurtigmat" />
        <Felt etikett="Tittel" name="tittel" placeholder="Slik lager du kaffe" required />
        <label className="felt"><span>Innhold</span>
          <textarea name="innhold" rows={8} required />
        </label>
        <div className="knapperad">
          <Knapp type="submit" variant="primar">Legg til anvisning</Knapp>
        </div>
      </form>
    </Sidepanel>
  ) : undefined

  // FANA HETER «HJELP», SIDA HETER «ANVISNINGER».
  //
  // Fana dekker mer enn dette — Lenker, Nyheter og Mine opplysninger
  // ligger i foten her, i stedet for som egne faner. «Hjelp» er derfor
  // riktig navn på inngangen.
  //
  // Men sida het også «Hjelp», og da forsvant ordet personalet faktisk
  // leter etter. Robert 2026-08-24, da han lette etter
  // monteringsanvisningene og ikke fant dem: «du kan kalle den
  // anvisninger på tablet også ja, men den kan ligge under hjelp.»
  //
  // Leter eieren etter «anvisninger» og ser «Hjelp», gjør antakelig hun
  // som står i butikken det samme. Innholdet er det samme som lederen
  // ser; bare hodet er kortere, og handlingene mangler.
  const paaNettbrett = bruker.rolle === 'butikkbruker_tablet'

  return (
    <>
      {paaNettbrett ? (
        <TabletHode tittel={o('Anvisninger')} undertittel={o('Slå opp når du trenger det.')} />
      ) : (
        <Sidehode
          tittel={o('Anvisninger')}
          undertittel={o('Prosedyrer og oppskrifter — slå opp når du trenger det.')}
          handlinger={nyPanel}
        />
      )}

      {kort.length === 0 ? (
        <Tomtilstand
          tittel={o('Ingen anvisninger ennå')}
          forklaring={o('Her legger dere prosedyrene folk må slå opp — hvordan '
            + 'kaffemaskinen rengjøres, hvordan pølsegrillen settes opp.')}
          handling={nyPanel}
        />
      ) : (
        <AnvisningListe
          rader={kort}
          erLeder={erLeder}
          tekst={{
            plassholder: o('Søk på ingrediens, tittel eller kategori'),
            ingenTreff: o('Ingen treff på'),
            merkelapp: o('Søk i anvisningene'),
          }}
        />
      )}
      <p className="undertittel">
        {kort.length} {kort.length === 1 ? o('anvisning') : o('anvisninger')}
      </p>

      {/* FOTEN. Tre ruter som hver hadde en fane eller en flis på hjem,
          og som alle svarer på det samme ærendet: «jeg trenger å vite
          noe». De mistet ikke en vei — de mistet en dublett, og fikk et
          sted der de hører sammen. */}
      {paaNettbrett && (
        <nav className="tablet-fot" aria-label={o('Mer hjelp')}>
          <Link href="/lenker" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Lenker')}</strong>
              <span className="undertittel">{o('Hurtiglenker for å hjelpe kunder')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
          <Link href="/nyheter" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Nyheter')}</strong>
              <span className="undertittel">{o('Oppdateringer og tips')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
          <Link href="/mine-opplysninger" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Slik måler vi')}</strong>
              <span className="undertittel">{o('Hva systemet lagrer om deg')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
        </nav>
      )}
    </>
  )
}
