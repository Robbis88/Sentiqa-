import { motBudsjett, type MotBudsjett } from './mot-budsjett'

// =====================================================================
// De fire regnskapstallene på eierens forside.
//
// HVORFOR DETTE IKKE LENGER LIGGER I DASHBORDET: tallene ble bygget der
// med en egen liten regel — `avvik >= 0 ? 'opp' : 'ned'` — og den regelen
// var feil for ett av dem. Lønn over budsjett sto med grønn pil opp,
// fordi tallet gikk opp.
//
// `motBudsjett` har løst nettopp dette hele tiden, for /regnskap:
// fortegnet følger pengene, dommen følger seksjonen. Front­siden skrev
// sin egen halvdel av regelen i stedet for å bruke den.
//
// TO TING FØLGER MED PÅ KJØPET, og begge er forbedringer vi ikke ba om:
//
//   Dødsonen. `motBudsjett` gir ingen dom når avviket er under to
//   prosent. Et regnskap som treffer innenfor to prosent har truffet,
//   og forsiden slutter dermed å farge budsjettpresisjon.
//
//   Manglende budsjett. Uten budsjett er det ingenting å avvike fra, og
//   tallet står uten sammenligning i stedet for å påstå 100 % avvik.
//
// Ren funksjon, uten database, nettopp fordi koblingen mellom «lønn» og
// «dette er en kostnad» er det som var galt. Den skal kunne bevises uten
// at noen seeder et regnskap.
// =====================================================================

export type Regnskapslinje = {
  seksjon: string
  post: string
  regnskap: number | null
  budsjett: number | null
}

export type Forsidetall = {
  /** Stabil nøkkel, uavhengig av teksten på merkelappen. */
  kode: 'omsetning' | 'brutto' | 'resultat' | 'lonn'
  merke: string
  mot: MotBudsjett
}

/**
 * Hvilke fire, og hvilken vei de peker.
 *
 * `kostnad` er hele forskjellen mellom de tre første og den siste, og
 * den står her framfor å bli utledet av navnet: en post som heter noe
 * annet i morgen skal ikke stille bytte fortegn på dommen.
 */
const TALLENE = [
  { kode: 'omsetning', merke: 'Omsetning', seksjon: 'omsetning', post: /^omsetning totalt/i, kostnad: false },
  { kode: 'brutto', merke: 'Bruttofortjeneste', seksjon: 'bruttofortjeneste', post: /^bruttofortjeneste totalt/i, kostnad: false },
  { kode: 'resultat', merke: 'Resultat (ex 9900)', seksjon: 'resultat', post: /ex 9900/i, kostnad: false },
  // Lønn måles mot LØNNSBUDSJETTET, ikke mot omsetningen. Og over
  // budsjett er dårlig — det var dette som sto grønt.
  { kode: 'lonn', merke: 'Lønn vs budsjett', seksjon: 'driftskostnader', post: /personalkostnad ex 9900/i, kostnad: true },
] as const

export function forsidetall(linjer: Regnskapslinje[]): Forsidetall[] {
  const ut: Forsidetall[] = []
  for (const t of TALLENE) {
    const l = linjer.find((x) => x.seksjon === t.seksjon && t.post.test(x.post))
    if (!l) continue
    ut.push({ kode: t.kode, merke: t.merke, mot: motBudsjett(l.regnskap, l.budsjett, t.kostnad) })
  }
  return ut
}
