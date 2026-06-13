import type { Metadata } from 'next'
import { Landing } from '@/components/lp/landing'
import '@/components/lp/lp.css'

export const metadata: Metadata = {
  title: 'Sentiqa — Fornemmer. Forstår. Forutser.',
  description:
    'AI-drevet driftsplattform for servicehandelen. Fornemmer vær, trafikk og trender — forstår tallene — forutser hva som kommer. Mindre tid på kontoret, mer tid i butikken.',
}

export default function Hjem() {
  return <Landing />
}
