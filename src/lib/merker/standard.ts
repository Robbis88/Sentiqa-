// Standard anerkjennelses-merker for bensinstasjon. Tilpassbart per kjede.
export type StandardMerke = { emoji: string; navn: string; beskrivelse: string }

export const STANDARD_MERKER: StandardMerke[] = [
  { emoji: '🎓', navn: 'Ferdig opplært', beskrivelse: 'Fullført hele opplæringsplanen' },
  { emoji: '⭐', navn: 'Månedens ansatt', beskrivelse: 'Ekstra innsats denne måneden' },
  { emoji: '🌭', navn: 'Hurtigmat-mester', beskrivelse: 'Topp på pølser, burgere og service' },
  { emoji: '🤝', navn: 'Servicestjerne', beskrivelse: 'Strålende kundebehandling' },
  { emoji: '🧹', navn: 'Ryddegeneral', beskrivelse: 'Alltid blank og ryddig stasjon' },
  { emoji: '🏆', navn: 'Konkurransevinner', beskrivelse: 'Vant en intern konkurranse' },
  { emoji: '💪', navn: 'Stødig vakt', beskrivelse: 'Pålitelig på hver eneste vakt' },
  { emoji: '🚀', navn: 'Rakettstart', beskrivelse: 'Imponerende start som nyansatt' },
]
