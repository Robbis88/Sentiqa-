// =====================================================================
// Svaret fra assistenten, delt opp så det kan tegnes.
//
// AI-boblen viste hele svaret i én `<p>`. Linjeskift forsvant, og
// markdown sto som tegn: «**Merk:** ... ### Salg ... |---|---|».
// Skjermbildet fra 2026-08-24 var ett avsnitt der tre tabeller og fire
// overskrifter hadde smeltet sammen.
//
// FØRSTE FORSØK VAR Å BE MODELLEN LA VÆRE. Det virker, men det er
// promptet som tilpasses flata i stedet for omvendt — og modellen vil
// uansett skrive en liste når svaret ER en liste.
//
// Derfor: en liten parser for det som faktisk trengs. Avsnitt, punktliste
// og uthevet tekst. IKKE tabeller — boblen er 320 px bred, og en tabell
// der blir uleselig uansett hvor pent den er tegnet. Modellen får
// fortsatt beskjed om å skrive én linje per stasjon.
//
// INGEN HTML. Blokkene tegnes som React-elementer, ikke via
// `dangerouslySetInnerHTML`. Teksten kommer fra en modell som leser
// data brukere har skrevet — oppgavetitler, fokuspunkter — og det er
// ikke et sted å stole på at ingenting ligner et script.
// =====================================================================

export type Bit =
  | { type: 'tekst'; verdi: string }
  | { type: 'uthevet'; verdi: string }

export type Blokk =
  | { type: 'avsnitt'; biter: Bit[] }
  | { type: 'liste'; punkter: Bit[][] }

const PUNKT = /^\s*[-*•]\s+/
// «### Overskrift» og «## Overskrift» — modellen skal ikke bruke dem,
// men gjør den det, skal de leses som uthevet linje og ikke som firkanter.
const OVERSKRIFT = /^\s*#{1,6}\s+/

/** Deler én linje på `**uthevet**`. Ubalanserte stjerner blir stående som tegn. */
export function biter(linje: string): Bit[] {
  const ut: Bit[] = []
  let rest = linje
  for (;;) {
    const start = rest.indexOf('**')
    if (start === -1) break
    const slutt = rest.indexOf('**', start + 2)
    if (slutt === -1) break
    // Tomt par (`****`) er ikke utheving — la det stå.
    if (slutt === start + 2) {
      const før = rest.slice(0, start + 4)
      if (før) ut.push({ type: 'tekst', verdi: før })
      rest = rest.slice(start + 4)
      continue
    }
    if (start > 0) ut.push({ type: 'tekst', verdi: rest.slice(0, start) })
    ut.push({ type: 'uthevet', verdi: rest.slice(start + 2, slutt) })
    rest = rest.slice(slutt + 2)
  }
  if (rest) ut.push({ type: 'tekst', verdi: rest })
  return ut.length > 0 ? ut : [{ type: 'tekst', verdi: '' }]
}

/**
 * Deler svaret i blokker.
 *
 * Tomme linjer skiller avsnitt. Linjer som begynner med `-`, `*` eller
 * `•` samles til én liste. Alt annet blir avsnitt.
 */
export function blokker(tekst: string): Blokk[] {
  const ut: Blokk[] = []
  let avsnitt: string[] = []
  let liste: string[] = []

  const lukkAvsnitt = () => {
    if (avsnitt.length === 0) return
    ut.push({ type: 'avsnitt', biter: biter(avsnitt.join(' ')) })
    avsnitt = []
  }
  const lukkListe = () => {
    if (liste.length === 0) return
    ut.push({ type: 'liste', punkter: liste.map(biter) })
    liste = []
  }

  for (const rå of tekst.split('\n')) {
    const linje = rå.trimEnd()
    if (linje.trim() === '') {
      lukkListe(); lukkAvsnitt()
      continue
    }
    if (PUNKT.test(linje)) {
      lukkAvsnitt()
      liste.push(linje.replace(PUNKT, ''))
      continue
    }
    lukkListe()
    if (OVERSKRIFT.test(linje)) {
      lukkAvsnitt()
      // En overskrift er sin egen linje, uthevet.
      ut.push({ type: 'avsnitt', biter: [{ type: 'uthevet', verdi: linje.replace(OVERSKRIFT, '') }] })
      continue
    }
    avsnitt.push(linje)
  }
  lukkListe(); lukkAvsnitt()
  return ut
}
