import type { Varekandidat } from './varesok'

/** Koden alene sier ikke om dette er en vare, vekt eller en kassepost. */
export function varegrunn(vare: Varekandidat): 'ikke_vare' | 'ukjent_enhet' | null {
  const norm = (s: string | null) => (s ?? '').trim().toUpperCase()
  const ikkeVare = new Set(['ENERGI', 'PANT', 'CR', 'KASSEREGULERING', 'RABATT'])
  if (ikkeVare.has(norm(vare.avdelingNavn)) || ikkeVare.has(norm(vare.varegruppeNavn))) return 'ikke_vare'
  // En pakke merket «1 KG» er ikke i seg selv en vektvare.
  const tekst = [vare.navn, vare.varegruppeNavn].join(' ').toUpperCase()
  return /\b(?:LØSVEKT|VEKTVARER?|(?:PR\.?|PER)\s*KG)\b/.test(tekst) ? 'ukjent_enhet' : null
}
