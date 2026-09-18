export type RapportModus = 'maaned' | 'hittil'

export type RapportKontekst = {
  stasjonId: string | null
  modus: RapportModus
  fra: string
  til: string
  periode: string
  etikett: string
}

export function lagRapportKontekst(args: {
  stasjonId?: string | null
  periode: string
  modus?: RapportModus
}): RapportKontekst {
  const modus = args.modus ?? 'maaned'
  const til = args.periode.length === 7 ? `${args.periode}-01` : args.periode
  const aar = til.slice(0, 4)
  return {
    stasjonId: args.stasjonId ?? null,
    modus,
    fra: modus === 'hittil' ? `${aar}-01-01` : til,
    til,
    periode: til.slice(0, 7),
    etikett: modus === 'hittil' ? `Hittil i år ${aar}` : new Intl.DateTimeFormat('nb-NO', { month: 'long', year: 'numeric' }).format(new Date(`${til}T12:00:00`)),
  }
}
