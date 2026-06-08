// St1-standard kontrollpunkter for IK-mat (fra de faktiske skjemaene).
// Krav: kjøl maks +4°C, frys maks −18°C, oppvarming hamburger min +72°C /
// pølser min +65°C, varmholding min +60°C (rullegrill 1 sone +65°C),
// skyllevann min +70°C.
export type StandardPunkt = {
  navn: string
  type: 'kjol' | 'frys' | 'oppvarming' | 'varmholding' | 'skyllevann'
  min_temp: number | null
  max_temp: number | null
  frekvens: 'daglig' | 'to_ukentlig' | 'ukentlig'
}

export const STANDARD_KONTROLLPUNKTER: StandardPunkt[] = [
  // Daglig – kjøl/frys
  { navn: 'Kjøleskap baguette', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  { navn: 'Kjøleskuff pølser', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  { navn: 'Granityr pølser', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  { navn: 'Kjøleskuff bakbenk', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  { navn: 'Granityr bakbenk', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  { navn: 'Fryseskuff burger', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Fryseskap kjøkken', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Fryseskap butikk', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Isdisk stor', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Isdisk liten', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Frys 1', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Frys 2', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Frys 3', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Frys 4', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Frys 5', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Frys 6', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Isdisk lager', type: 'frys', min_temp: null, max_temp: -18, frekvens: 'daglig' },
  { navn: 'Kjøleskap lager', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  { navn: 'Kjøl', type: 'kjol', min_temp: null, max_temp: 4, frekvens: 'daglig' },
  // 2 g/uke – oppvarming/varmholding (kjernetemperatur)
  { navn: 'Hamburger, oppvarming', type: 'oppvarming', min_temp: 72, max_temp: null, frekvens: 'to_ukentlig' },
  { navn: 'Pølsekoker, oppvarming', type: 'oppvarming', min_temp: 65, max_temp: null, frekvens: 'to_ukentlig' },
  { navn: 'Rullegrill, oppvarming', type: 'oppvarming', min_temp: 65, max_temp: null, frekvens: 'to_ukentlig' },
  { navn: 'Flatgrill, oppvarming', type: 'oppvarming', min_temp: 65, max_temp: null, frekvens: 'to_ukentlig' },
  { navn: 'Rullegrill, varmholding', type: 'varmholding', min_temp: 65, max_temp: null, frekvens: 'to_ukentlig' },
  { navn: 'Flatgrill, varmholding', type: 'varmholding', min_temp: 60, max_temp: null, frekvens: 'to_ukentlig' },
  // Ukentlig – skyllevann oppvaskmaskin
  { navn: 'Skyllevann', type: 'skyllevann', min_temp: 70, max_temp: null, frekvens: 'ukentlig' },
]

export const FREKVENS_ETIKETT: Record<string, string> = {
  daglig: 'Daglig',
  to_ukentlig: '2 ganger i uka',
  ukentlig: 'Ukentlig',
}

export const TYPE_ETIKETT: Record<string, string> = {
  kjol: 'Kjøl',
  frys: 'Frys',
  oppvarming: 'Oppvarming',
  varmholding: 'Varmholding',
  skyllevann: 'Skyllevann',
  annet: 'Annet',
}

// Tekstlig krav for visning.
export function kravTekst(min: number | null, max: number | null): string {
  if (max != null) return `Maks ${max}°C`
  if (min != null) return `Min +${min}°C`
  return '—'
}
