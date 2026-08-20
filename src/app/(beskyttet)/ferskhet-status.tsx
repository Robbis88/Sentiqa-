import { ferskhet } from '@/lib/signaler'
import { datoLang } from '@/lib/format'
import { Status } from '@/components/ui/status'

// =====================================================================
// Hvor gamle er tallene under?
//
// Delt mellom butikksjefens og eierens forside, saa de to flatene sier
// det paa samme maate. `ferskhet()` er uroert — den avgjoer fortsatt hva
// som er fersk, sent og gammelt (signaler.ts). Her oversettes bare de
// tre til systemets egne statusnivaaer.
//
// DETTE ER IKKE PYNT PAA EN DATO. Fra og med nattlig import er dette
// det eneste stedet som roeper at roerledningen har stoppet, og da er
// alt annet paa sida gammelt uten aa se gammelt ut.
//
//   fersk    normal    dagen etter er normaltilstanden, ikke et avvik
//   sen      handling  noen maa se paa importen
//   gammel   kritisk   importen har trolig stoppet
// =====================================================================

const NIVAA = { fersk: 'normal', sen: 'handling', gammel: 'kritisk' } as const

export function Ferskhetsstatus({
  dato, idag, merke = 'Siste salgsdag',
}: { dato: string; idag: string; merke?: string }) {
  const f = ferskhet(dato, idag)
  return (
    <Status nivaa={NIVAA[f.nivaa]}>
      {merke} {datoLang.format(new Date(`${dato}T12:00:00Z`))}
      {f.tekst ? ` · ${f.tekst}` : ''}
    </Status>
  )
}
