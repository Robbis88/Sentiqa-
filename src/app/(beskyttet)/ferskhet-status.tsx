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
    // FUNN F, RETTET 2026-09-01.
    //
    // `Status` er laget for KORT tilstand og har `white-space: nowrap`,
    // slik at «3 avvik» aldri brytes mellom tallet og ordet. Denne
    // komponenten legger en hel setning i den — «Siste salgsdag
    // 1. september 2026 · …» — og paa 390 px ble den 582 px bred i en
    // 362 px ramme.
    //
    // Teksten kan ikke kortes nok: selv med kort datoformat er den for
    // lang for spalta. Og `Status` skal IKKE faa en `className`-parameter
    // for at ett kallsted skal slippe unna kontrakten sin — det er samme
    // luke som `Sideramme` med vilje ikke har.
    //
    // Derfor eier kallstedet unntaket sitt, med et navn som sier hva det
    // er: her, og bare her, er statusen en setning og kan brytes.
    <span className="ferskhet-lang">
      <Status nivaa={NIVAA[f.nivaa]}>
        {merke} {datoLang.format(new Date(`${dato}T12:00:00Z`))}
        {f.tekst ? ` · ${f.tekst}` : ''}
      </Status>
    </span>
  )
}
