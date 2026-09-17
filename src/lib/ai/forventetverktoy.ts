import 'server-only'
import type Anthropic from '@anthropic-ai/sdk'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { byggSvar } from './svar'
import { hentScope, velgStasjoner, etikett } from './scope'
import { idagOslo } from './periode'
import { leggTilDager } from '@/lib/produksjonsplan'
import { forventetSalg, MODELLER, type Salgsrad } from '@/lib/forventet/motor'
import { maalTreff, tillit, type Treffmaal } from '@/lib/forventet/treffsikkerhet'
import { slaaOpp, spoersmaal, type Varerad } from '@/lib/forventet/varesok'

// =====================================================================
// AI SPØR MOTOREN. AI REGNER IKKE.
// =====================================================================
//
// Hele verktøyet er ett grensesnitt:
//
//   spørsmål → autorisert stasjon → strukturell vare → forventet-salg
//   → historisk treffsikkerhet → menneskelig svar
//
// Det finnes ingen prognoseformel her. Skulle assistenten hente fem
// historiske tall og resonnere seg til et antall, ville Sentiqa hatt to
// forventninger som lignet på hverandre — og den ene ville ingen eie.
//
// ---------------------------------------------------------------------
// TRE SANNHETER SOM HOLDES FRA HVERANDRE
// ---------------------------------------------------------------------
//
//   1  FORVENTNINGEN     `forventetSalg`. Finnes den ikke, gir vi intet tall.
//   2  TREFFSIKKERHETEN  `maalTreff`. Beskriver hvordan modellen HAR gjort
//                        det. Endrer aldri tallet.
//   3  PRESENTASJONEN    assistentens jobb, og bare den.
//
// Svak treffsikkerhet stopper ikke svaret. Den endrer hvordan det sies.
// Derfor står det ingen terskel her som returnerer `null` på høy feil —
// motoren bestemmer om en forventning finnes, målingen beskriver hvor
// godt den har fungert, og AI bestemmer ingen av delene.
//
// ---------------------------------------------------------------------
// «22 % HISTORISK FEIL» ER IKKE «38 ± 22 %»
// ---------------------------------------------------------------------
//
// Resultatet bærer ingen `fra`, `til`, `intervall` eller `konfidens`.
// Vi har ikke bevist at feilen er fordelt slik at et spenn betyr noe, og
// et intervall som ser statistisk ut uten å være det er verre enn ingen.
//
// Det som ikke kan uttrykkes i typen, kan ikke lekke ut i et svar.
//
// ---------------------------------------------------------------------
// HORISONTEN ER +1, OG DET ER LÅST
// ---------------------------------------------------------------------
//
// Backtesten har bare godkjent dagen etter. Spør noen om neste uke, sier
// verktøyet det — det faller ikke tilbake på et historisk snitt og
// kaller det en prognose.
//
// ---------------------------------------------------------------------
// TILGANG HÅNDHEVES SERVER-SIDE
// ---------------------------------------------------------------------
//
// `hentScope` + `velgStasjoner` avgjør hvilke stasjoner som finnes for
// denne brukeren. Ber modellen om en annen, står den i `utenfor` og får
// aldri tall. Vi stoler ikke på at språkmodellen lar være å spørre.
// =====================================================================

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>
type Ktx = { supabase: Klient; bruker: InnloggetBruker }

/**
 * Modellen og terskelen backtesten forsvarte.
 *
 * Målt 2026-09-17: `basis+trend` ved 60+ salgsdager ga 55,6 % wMAPE mot
 * 71,8 % ved terskel 30, og været var inert (0,2 pp, feil vei). Tallene
 * er ikke valgt her — de er lest av målingen.
 */
const MODELL = MODELLER.find((m) => m.navn === 'basis+trend')!
const MINST_DAGER = 60

/** Måldatoene treffsikkerheten måles over. Fire uker. */
const TREFF_DAGER = 28

/** Historikkvindu: fjorårsmatch (−364) + 28 dagers nylig + margin. */
const HISTORIKK_DAGER = 364 + 28 + 40

export type Forventetsvar = {
  stasjon: string
  ean: string
  varenavn: string
  varegruppe: string | null
  dato: string
  horisont: string
  forventetAntall: number | null
  dekning: 'beregnet' | 'ikke_dekning'
  /** Bare satt når motoren tidde. */
  grunn?: string
  grunnlag?: { basis: number; trendfaktor: number; dagerMedSalg: number }
  historiskTreffsikkerhet: (Treffmaal & { tillit: string }) | null
}

async function hentSalg(
  supabase: Klient, stasjonIder: string[], ean: string, fra: string, til: string,
): Promise<Salgsrad[]> {
  const ut: Salgsrad[] = []
  const SIDE = 1000
  for (let f = 0; ; f += SIDE) {
    const { data } = await supabase
      .from('v_butikksalg')
      .select('stasjon_id, dato, ean, antall, varegruppe_kode, varegruppe_navn')
      .eq('ean', ean).in('stasjon_id', stasjonIder)
      .gte('dato', fra).lte('dato', til)
      .order('dato', { ascending: true }).range(f, f + SIDE - 1)
      .overrideTypes<{
        stasjon_id: string; dato: string; ean: string; antall: number | null
        varegruppe_kode: string | null; varegruppe_navn: string | null
      }[]>()
    const side = data ?? []
    for (const r of side) {
      ut.push({
        stasjonId: r.stasjon_id, ean: r.ean, dato: r.dato, antall: r.antall ?? 0,
        varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn,
      })
    }
    if (side.length < SIDE) break
  }
  return ut
}

export const forventetSalgVerktoy: {
  schema: Anthropic.Tool
  kjor: (input: Record<string, unknown>, ktx: Ktx) => Promise<unknown>
} = {
  schema: {
    name: 'forventet_salg',
    description:
      'Hva Sentiqa forventer at en vare selger PÅ EN STASJON I MORGEN. '
      + 'Bruk denne når noen spør hvor mye vi kommer til å selge av noe. '
      + 'Du skal ALDRI regne ut en forventning selv fra historiske tall — '
      + 'dette verktøyet eier svaret. Prognosen finnes bare for dagen '
      + 'etter i dag; spør noen om neste uke eller en annen dag, si at '
      + 'Sentiqa foreløpig bare har godkjent prognose for neste dag. '
      + 'Verktøyet gir også hvor godt modellen HAR truffet historisk på '
      + 'nettopp denne varen og stasjonen. Det er en observasjon om '
      + 'modellen — ikke et usikkerhetsintervall. Si aldri «38 ± 22 %» '
      + 'eller «30–46 stk».',
    input_schema: {
      type: 'object',
      properties: {
        vare: {
          type: 'string',
          description:
            'Hva brukeren spurte om, med brukerens egne ord — «Coca-Cola '
            + 'Zero», «cola 0,5». Eller en EAN hvis du alt har den fra et '
            + 'tidligere svar i samtalen.',
        },
        // HUSETS KONTRAKT ER EN LISTE. `katalogvakt` krever at hvert
        // leseverktoey tar `stasjoner`, saa modellen kan velge scope paa
        // samme maate overalt - og saa «Hva med Boenes?» kan endre ÉN
        // dimensjon uten at samtalen maa laere et nytt felt.
        stasjoner: {
          type: 'array',
          items: { type: 'string' },
          description:
            'Butikknummer eller stasjonsnavn. Utelat for ALLE stasjoner '
            + 'brukeren har tilgang til.',
        },
      },
      required: ['vare'],
    },
  },

  async kjor(input, { supabase, bruker }) {
    const scope = await hentScope(supabase, bruker.rolle)
    if ('feil' in scope) {
      return byggSvar({ domene: 'forventet_salg', kilder: ['v_butikksalg'], feil: scope.feil })
    }
    const { valgte, utenfor } = velgStasjoner(scope, input.stasjoner)
    if (valgte.length === 0) {
      // BER MODELLEN OM EN STASJON BRUKEREN IKKE HAR, FÅR DEN INGEN TALL.
      // `byggSvar` nevner den uten å bekrefte at den finnes.
      return byggSvar({
        domene: 'forventet_salg', kilder: ['v_butikksalg'],
        scope: { forespurt: [], utenfor_tilgang: utenfor },
        ingenTilgang: true,
      })
    }

    const idag = idagOslo()
    const maalDato = leggTilDager(idag, 1)
    const fra = leggTilDager(idag, -HISTORIKK_DAGER)
    const soek = typeof input.vare === 'string' ? input.vare.trim() : ''
    if (!soek) {
      return byggSvar({
        domene: 'forventet_salg', kilder: ['v_butikksalg'],
        feil: 'Ingen vare oppgitt.',
      })
    }

    // ── RESOLVEREN: navn finner, EAN identifiserer ──────────────────────
    //
    // Søkevinduet er kort med vilje (90 dager): en vare som ikke har vært
    // solgt på tre måneder er ikke den brukeren spør om i morgen.
    const { data: sokRader } = await supabase
      .from('v_butikksalg')
      .select('ean, varenavn, varegruppe_kode, varegruppe_navn, avdeling_navn, antall, dato, stasjon_id')
      .in('stasjon_id', valgte.map((s) => s.id))
      .gte('dato', leggTilDager(idag, -90)).lte('dato', idag)
      .limit(20_000).overrideTypes<Varerad[]>()

    const oppslag = slaaOpp(sokRader ?? [], soek)
    if (oppslag.slag === 'ingen') {
      return byggSvar({
        domene: 'forventet_salg', kilder: ['v_butikksalg'],
        scope: { forespurt: valgte.map((s) => s.butikknummer), utenfor_tilgang: utenfor },
        // =============================================================
        // INGEN KANDIDAT ER IKKE INGEN SALGSHISTORIKK
        // =============================================================
        //
        // Målt på preview 2026-09-17: modellen søkte «Coca Cola», fikk
        // null rader, og svarte at varen «er enten registrert under et
        // annet navn … eller den er ikke i sortimentet».
        //
        // Den siste halvdelen er ikke bevist av noe. Varen har 432
        // salgsdager på Dale. Et oppslag som ikke fant en sikker match
        // er et utsagn om SØKET — ikke om butikken.
        //
        // Merknaden sier derfor hva som skjedde, og forbyr eksplisitt de
        // slutningene modellen tok. Vakta ligger på denne teksten, ikke
        // bare på `Oppslag`-unionen: unionen var riktig hele tiden, og
        // det var formuleringen som løy.
        merknad: [
          `Oppslaget fant ingen sikker varematch på «${soek}» i salget de `
          + 'siste 90 dagene på de stasjonene brukeren har tilgang til.',
          'DETTE SIER INGENTING OM SORTIMENTET. Du vet ikke om varen '
          + 'selges, om den finnes, eller om den har salgshistorikk — bare '
          + 'at søket ikke traff. Si aldri «ikke i sortimentet», «selges '
          + 'ikke», «ingen salgshistorikk», «ikke registrert» eller «finnes '
          + 'ikke». Spekuler heller ikke i hvorfor.',
          'Si at du ikke finner en sikker varematch, og be om et annet navn.',
        ],
      })
    }
    if (oppslag.slag === 'flere') {
      // VELGER ALDRI STILLE. Fire ulike EAN kan naturlig forstås som
      // «Coca-Cola uten sukker» — den mest solgte ville gitt riktig svar
      // fire av fem ganger og feil svar usett.
      return byggSvar({
        domene: 'forventet_salg', kilder: ['v_butikksalg'],
        scope: { forespurt: valgte.map((s) => s.butikknummer), utenfor_tilgang: utenfor },
        data: oppslag.kandidater.slice(0, 6).map((k) => ({
          ean: k.ean, navn: k.navn, varegruppe: k.varegruppeNavn,
        })),
        merknad: [
          'FLERE VARER PASSER. Spør brukeren hvilken — ikke velg selv, og '
          + 'ikke gi noe tall før du har fått svar.',
          spoersmaal(oppslag.kandidater),
        ],
      })
    }

    const vare = oppslag.vare
    const salg = await hentSalg(supabase, valgte.map((s) => s.id), vare.ean, fra, idag)

    const maaldatoer: string[] = []
    for (let i = TREFF_DAGER; i >= 1; i--) maaldatoer.push(leggTilDager(idag, -i))

    const svar: Forventetsvar[] = valgte.map((s) => {
      const enhet = { stasjonId: s.id, ean: vare.ean }
      const f = forventetSalg({
        enhet, maalDato, salg, modell: MODELL, minstDagerMedSalg: MINST_DAGER,
      })
      // MÅLINGEN KJØRES UANSETT. Svak treffsikkerhet stopper ikke svaret;
      // den endrer hvordan det sies.
      const m = maalTreff({
        enhet, salg, maaldatoer, modell: MODELL, minstDagerMedSalg: MINST_DAGER,
      })
      return {
        stasjon: etikett(s),
        ean: vare.ean,
        varenavn: vare.navn,
        varegruppe: vare.varegruppeNavn,
        dato: maalDato,
        horisont: 'i morgen',
        forventetAntall: f.slag === 'beregnet' ? f.antall : null,
        dekning: f.slag === 'beregnet' ? 'beregnet' : 'ikke_dekning',
        ...(f.slag === 'ikke_dekning' ? { grunn: f.grunn } : {}),
        ...(f.slag === 'beregnet'
          ? {
            grunnlag: {
              basis: f.grunnlag.basis,
              trendfaktor: f.grunnlag.trendfaktor,
              dagerMedSalg: f.grunnlag.dagerMedSalg,
            },
          }
          : {}),
        historiskTreffsikkerhet: m ? { ...m, tillit: tillit(m) } : null,
      }
    })

    return byggSvar({
      domene: 'forventet_salg',
      kilder: ['v_butikksalg'],
      data: svar,
      scope: {
        forespurt: valgte.map((s) => s.butikknummer),
        besvart: valgte.map((s) => s.butikknummer),
        utenfor_tilgang: utenfor,
      },
      merknad: [
        `Prognosen gjelder ${maalDato} — dagen etter i dag. Sentiqa har `
        + 'foreløpig ingen godkjent prognose for andre dager. Blir du spurt '
        + 'om neste uke eller en annen dato, si det i stedet for å svare.',
        'historiskTreffsikkerhet beskriver hvordan modellen HAR truffet på '
        + 'denne varen og stasjonen. Det er IKKE et usikkerhetsintervall — '
        + 'gjør det aldri om til et spenn rundt tallet.',
        'bias er en observasjon om modellen, ikke en korreksjon. Legg den '
        + 'aldri til forventningen.',
        'Svar i butikkspråk. Ikke gjengi wMAPE, MAE eller n som tall '
        + 'brukeren må tolke — si hvor godt prognosen pleier å treffe.',
        ...(svar.some((s) => s.dekning === 'ikke_dekning')
          ? ['For noen stasjoner finnes ingen forsvarlig forventning. Da gir '
            + 'du ikke noe tall for dem — heller ikke et anslag fra historikk.']
          : []),
      ],
    })
  },
}
