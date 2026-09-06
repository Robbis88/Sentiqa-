import type { Metadata } from 'next'
import { Landing } from '@/components/lp/landing'
import '@/components/lp/lp.css'

// TITTELEN LOVER DET SIDA VISER. Den sto som «Fornemmer. Forstår.
// Forutser.» — tre ord om vær og prognose, fra den gang det var det
// produktet var. I dag er det et driftssystem med ni datakilder, fire
// roller og over seksti flater, og tittelen er det første en søkende
// leser.
export const metadata: Metadata = {
  title: 'Sentiqa — hele driften, ett system',
  description:
    'Driftssystem for servicehandelen. Salg, bemanning, svinn, produksjon, regnskap og '
    + 'folk i ett bilde — bygget på rapportene du allerede får tilsendt. Selvbetjent '
    + 'oppstart, ingen systemer må byttes ut.',
}

export default function Hjem() {
  return <Landing />
}
