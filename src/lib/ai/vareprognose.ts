// =====================================================================
// PROGNOSE PER VARE — den rene delen.
//
// Motoren finnes fra før: `lagProduksjonsplan` regner forventet antall
// per produkt for én måldato, av fjorårets samme ukedag (median ±2 uker)
// pluss nylig trend, vær og kampanjedeteksjon. Ingenting i den er
// produksjonsspesifikt — begrensningen til bakevarer lå i kalleren.
//
// Denne fila gjør to ting motoren ikke gjør, og begge er nødvendige for
// at svaret skal kunne stoles på:
//
//   SJU DAGER    Motoren regner ÉN dato. En uke er sju kall, ikke ett
//                gjennomsnitt ganget med sju — mandag og lørdag er
//                forskjellige dager, og det er nettopp forskjellen
//                butikksjefen bestiller etter.
//
//   TOMME HYLLER Var varen utsolgt, står det null salg i basen. Motoren
//                leser det som «ingen ville ha den», og en uke uten varer
//                trekker prognosen ned — som gir en for liten bestilling,
//                som gir en ny tom uke. Det er den eneste feilmåten her
//                som forsterker seg selv.
//
// HVORFOR DAGENE ERSTATTES OG IKKE FJERNES.
//
// Første utgave FJERNET de utsolgte radene, med den begrunnelsen at å
// gjette hva varen ville solgt er en modell oppå en modell. Testen viste
// at det ikke virket i det hele tatt: motoren regner trenden som en
// TOTAL over et fast kalendervindu (`trendNaa += r.antall`), så en dag
// uten rad teller nøyaktig som en dag med null.
//
// Derfor erstattes de i stedet, med medianen for samme ukedag blant
// dagene varen FAKTISK var å få kjøpt. Det er ikke en gjetning på hva
// som skjedde — det er den vanlige behandlingen av sensurert etterspørsel,
// og alternativet er ikke «ingen antakelse», det er antakelsen om at
// etterspørselen var null.
//
// Ren funksjon. Ingen database, ingen klokke — samme grunnlag gir samme
// prognose, og den kan derfor etterprøves.
// =====================================================================

import { lagProduksjonsplan, leggTilDager, type SalgsPunkt, type Vaerdag } from '@/lib/produksjonsplan'
import type { UtsolgtHendelse } from '@/lib/utsolgt'

export type Dagsprognose = {
  dato: string
  /** 0 = søndag. Tas med fordi ukedagen er hele forklaringen på tallet. */
  ukedag: number
  forventet: number
  /** Hva prognosen bygger på: medianen for ukedagen før justering. */
  basis: number
  /** Flagg fra motoren: `ny`, `fa_data`, `fjor_kampanje`, `paagaaende_kampanje`. */
  flagg: string[]
}

export type Vareprognose = {
  varenavn: string
  dager: Dagsprognose[]
  /** Summen av de sju dagene. Det er dette man bestiller etter. */
  sum: number
  /** Dager som ble holdt utenfor grunnlaget fordi varen var utsolgt. */
  utelatteDager: number
  /** Sagt rett ut, når prognosen ikke bør stoles på. */
  forbehold: string[]
}

/**
 * Datoene en vare var utsolgt.
 *
 * `finnUtsolgt` gir hendelser med `fra` og `til`. Her flates de ut til
 * enkeltdatoer, så de kan lukes ut av salgsgrunnlaget.
 */
export function utsolgtDatoer(hendelser: UtsolgtHendelse[]): Set<string> {
  const ut = new Set<string>()
  for (const h of hendelser) {
    let d = h.fra
    // Vinduet er få dager; en løkke med hard stopp er tryggere enn
    // aritmetikk som kan gå i ring på en ugyldig hendelse.
    for (let i = 0; i < 400 && d <= h.til; i++) {
      ut.add(d)
      d = leggTilDager(d, 1)
    }
  }
  return ut
}

/** Minste antall salgsdager før prognosen sier noe. Under dette er
    medianen bare den ene dagen som tilfeldigvis hadde et salg. */
export const MIN_DAGER = 8

const median = (xs: number[]): number => {
  if (xs.length === 0) return 0
  const s = [...xs].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

const ukedagFor = (iso: string) => new Date(`${iso}T12:00:00Z`).getUTCDay()

/**
 * Bytter ut salget på utsolgte dager med det varen normalt selger på den
 * ukedagen.
 *
 * Medianen tas over dagene varen VAR å få kjøpt. Finnes det ingen slike
 * for ukedagen, brukes medianen over alle tilgjengelige dager; finnes
 * ingenting, står raden som den er — vi har da ikke noe å erstatte den
 * med, og en oppdiktet verdi ville vært verre enn en ærlig null.
 */
export function erstattUtsolgt(salg: SalgsPunkt[], utsolgt: Set<string>): SalgsPunkt[] {
  if (utsolgt.size === 0) return salg
  const tilgjengelig = salg.filter((s) => !utsolgt.has(s.dato))
  if (tilgjengelig.length === 0) return salg

  const perUkedag = new Map<number, number[]>()
  for (const s of tilgjengelig) {
    const u = ukedagFor(s.dato)
    perUkedag.set(u, [...(perUkedag.get(u) ?? []), s.antall])
  }
  const alle = median(tilgjengelig.map((s) => s.antall))

  return salg.map((s) => {
    if (!utsolgt.has(s.dato)) return s
    const sammeUkedag = perUkedag.get(ukedagFor(s.dato)) ?? []
    return { ...s, antall: sammeUkedag.length > 0 ? median(sammeUkedag) : alle }
  })
}

export function lagVareprognose(opts: {
  varenavn: string
  /** Alt salg for varen: fjorårsvinduet OG siste 28 dager. */
  salg: SalgsPunkt[]
  /** Datoer varen var utsolgt — lukes ut av grunnlaget. */
  utsolgt: Set<string>
  /** Siste dag med faktiske salgstall. */
  sisteSalgsdato: string
  /** Første dag det skal spås for. */
  fraDato: string
  antallDager?: number
  vaerfolsomhet?: number
}): Vareprognose {
  const antall = opts.antallDager ?? 7

  const rent = erstattUtsolgt(opts.salg, opts.utsolgt)
  const utelatteDager = opts.salg.filter((s) => opts.utsolgt.has(s.dato)).length

  const dager: Dagsprognose[] = []
  const flaggSett = new Set<string>()

  for (let i = 0; i < antall; i++) {
    const dato = leggTilDager(opts.fraDato, i)
    const plan = lagProduksjonsplan({
      maalDato: dato,
      sisteSalgsdato: opts.sisteSalgsdato,
      salg: rent,
      vaerMaal: null as Vaerdag | null,
      vaerFjor: null as Vaerdag | null,
      vaerfolsomhet: opts.vaerfolsomhet ?? 0,
    })
    const p = plan.forslag.find((x) => x.varenavn === opts.varenavn) ?? plan.forslag[0]
    for (const f of p?.flagg ?? []) flaggSett.add(f)
    dager.push({
      dato,
      ukedag: new Date(`${dato}T12:00:00Z`).getUTCDay(),
      forventet: p ? Math.round(p.foreslatt) : 0,
      basis: p ? Math.round(p.basis) : 0,
      flagg: p?.flagg ?? [],
    })
  }

  const forbehold: string[] = []
  const salgsdager = new Set(rent.map((s) => s.dato)).size
  if (salgsdager < MIN_DAGER) {
    forbehold.push(
      `Bare ${salgsdager} dager med salg i grunnlaget. Under ${MIN_DAGER} er tallet `
      + 'en gjetning, ikke en prognose.',
    )
  }
  if (utelatteDager > 0) {
    forbehold.push(
      `${utelatteDager} dager er regnet som normalsalg fordi varen kan ha vært `
      + 'utsolgt. Uten det ville tomme hyller sett ut som lav etterspørsel, og '
      + 'neste bestilling blitt for liten.',
    )
  }
  if (flaggSett.has('ny')) forbehold.push('Varen er ny — det finnes ingen fjorårsdager å måle mot.')
  if (flaggSett.has('fa_data')) forbehold.push('Tynt datagrunnlag for denne varen.')
  if (flaggSett.has('fjor_kampanje')) forbehold.push('Fjoråret hadde kampanje i perioden. Basisen er trolig for høy.')
  if (flaggSett.has('paagaaende_kampanje')) forbehold.push('Det er kampanje nå. Prognosen fanger den bare delvis.')

  return {
    varenavn: opts.varenavn,
    dager,
    sum: dager.reduce((a, d) => a + d.forventet, 0),
    utelatteDager,
    forbehold,
  }
}
