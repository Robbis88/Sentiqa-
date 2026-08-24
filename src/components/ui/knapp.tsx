import type { ButtonHTMLAttributes, ReactNode } from 'react'

// =====================================================================
// Knappen.
//
// BYGGER PÅ KLASSEN SOM FINNES, ikke ved siden av den. `.sq-knapp` er
// brukt direkte på et hundretalls steder i dag. Et nytt sett klasser
// hadde gitt to knappesystemer som ser nesten like ut — og «nesten»
// er den dyreste tilstanden et designsystem kan være i.
//
// FIRE VARIANTER. Ikke ti. Hver ekstra variant er et valg noen må ta
// hver gang de skriver en knapp, og valget er som regel «den som ser
// finest ut» framfor «den som betyr riktig».
//
//   primar      Det siden vil du skal gjøre. Én per skjerm.
//
//               REGELEN, fra PORT 3: primær = fullfører et skjema. Et
//               felt og en knapp ved siden av hverandre skal ikke ha
//               samme vekt — feltet er verdien, knappen er handlingen.
//               «Dag [25.08.2026] [Vis dagen]» hadde to hvite bokser og
//               ingenting som sa hvilken av dem som gjorde noe.
//
//               Unntaket er vekslere: `.kryss`, `.janei` og liknende
//               fullfører teknisk et skjema, men har sitt eget visuelle
//               språk og skal ikke rope.
//   sekundaer   Alt annet som er trygt.
//   ghost       Handling som ikke skal konkurrere — «Avbryt», «Rediger».
//   destruktiv  Sletter eller opphever noe. Rød KANT, ikke rød flate:
//               en fylt rød knapp roper like høyt som en kritisk feil,
//               og da betyr rødt to ting på samme skjerm.
//
// IKON ER VALGFRITT OG ALDRI PÅKREVD. En knapp som må ha et ikon
// tvinger fram ikoner som ikke betyr noe.
// =====================================================================

export type Knappevariant = 'primar' | 'sekundaer' | 'ghost' | 'destruktiv'

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Knappevariant
  /** Vises før teksten. Skal være aria-hidden — teksten er navnet. */
  ikon?: ReactNode
  /** Kompakt utgave for tette rader. Fortsatt over 32 px høy. */
  liten?: boolean
  children: ReactNode
}

const KLASSE: Record<Knappevariant, string> = {
  primar: 'sq-knapp primar',
  sekundaer: 'sq-knapp',
  ghost: 'sq-knapp sq-ghost',
  destruktiv: 'sq-knapp sq-destruktiv',
}

export function Knapp({
  variant = 'sekundaer',
  ikon,
  liten,
  children,
  className,
  type = 'button',
  ...rest
}: Props) {
  return (
    <button
      type={type}
      className={[KLASSE[variant], liten && 'liten', className]
        .filter(Boolean).join(' ')}
      {...rest}
    >
      {ikon}
      {children}
    </button>
  )
}
