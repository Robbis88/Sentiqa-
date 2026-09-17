import { gyldigDato, leggTilDager } from './periode'
import { MAKS_HORISONT_DAGER, MAKS_PERIODE_DAGER } from '@/lib/forventet/periode'

export function prognosePeriode(input: Record<string, unknown>, idag: string): { fra: string; til: string; datoer: string[]; horisontDager: number } | { feil: string } {
  if (input.maaned != null || input.aar != null) return { feil: 'Måneds- og årsprognose er ikke godkjent.' }
  if (['fra', 'til', 'dato', 'periode'].some((felt) => input[felt] != null && typeof input[felt] !== 'string')) return { feil: 'Datoer og periode må være tekst.' }
  if (input.fra != null && input.dato != null && input.fra !== input.dato) return { feil: 'Motstridende startdatoer.' }
  let fra = typeof input.fra === 'string' ? input.fra : typeof input.dato === 'string' ? input.dato : undefined
  let til = typeof input.til === 'string' ? input.til : undefined
  if (input.periode != null) {
    if (fra || til) return { feil: 'Velg periode eller fra/til, ikke begge.' }
    if (input.periode === 'neste uke') {
      const ukedag = new Date(`${idag}T00:00:00Z`).getUTCDay()
      fra = leggTilDager(idag, ((8 - ukedag) % 7) || 7)
      til = leggTilDager(fra, 6)
    } else {
      const match = /^neste ([1-7]) dager$/.exec(String(input.periode))
      if (!match) return { feil: 'Velg neste uke, neste 1–7 dager eller konkrete datoer. Måned er ikke godkjent.' }
      fra = leggTilDager(idag, 1)
      til = leggTilDager(idag, Number(match[1]))
    }
  }
  fra ??= til ?? leggTilDager(idag, 1)
  til ??= fra
  if (!gyldigDato(fra) || !gyldigDato(til) || fra > til) return { feil: 'Ugyldig prognoseperiode.' }
  if (fra <= idag || til > leggTilDager(idag, MAKS_HORISONT_DAGER) || til > leggTilDager(fra, MAKS_PERIODE_DAGER - 1)) {
    return { feil: 'Prognosen dekker maksimalt 7 dager, tidligst i morgen og senest 13 dager fram. En tidligere prognose må hentes for en ny framtidig periode.' }
  }
  const datoer: string[] = []
  for (let d = fra; d <= til; d = leggTilDager(d, 1)) datoer.push(d)
  const horisontDager = Math.round((new Date(`${fra}T00:00:00Z`).getTime() - new Date(`${idag}T00:00:00Z`).getTime()) / 86_400_000)
  return { fra, til, datoer, horisontDager }
}
