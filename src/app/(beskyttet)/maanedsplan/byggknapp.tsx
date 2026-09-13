import { HandlingKnapp } from '@/components/ui/handling-knapp'
import { Forklaring } from '@/components/ui/side'
import { maanedsnavn } from '@/lib/kurs/plan'
import { byggPlanerPaaNytt } from './handlinger'

// =====================================================================
// «Bygg månedens utkast på nytt fra eksisterende data»
// =====================================================================
//
// Eierens egen knapp. Den finnes fordi den eneste veien til et nytt
// utkast var å kjøre en regnskapsfil om igjen — og det skriver
// `regnskapslinjer`, `bilagssum`, `bp_linje` og provenienstabellene på
// veien. For fem nye utkast ville vi rørt hele grunnlaget.
//
// ---------------------------------------------------------------------
// DEN KJØRER ALDRI AV SEG SELV
//
// Ingen `useEffect`, ingen kjøring ved sidevisning. Et knappetrykk, og
// et spørsmål før det. Det som skrives om er eierens egne utkast, og en
// side som skriver når den åpnes er en side ingen kan stole på.
//
// ---------------------------------------------------------------------
// TO TALL, HVER FOR SEG
//
// Hvor mange stasjoner DATAGRUNNLAGET forventer, og hvor mange planer
// som allerede finnes. Er de ulike, mangler det planer — og det er
// nettopp da man vil se begge. Ett tall ville skjult forskjellen, og
// det er den forskjellen knappen finnes for å lukke.
//
// ---------------------------------------------------------------------
// SPØRSMÅLET SIER HVA SOM SKJER, IKKE «ER DU SIKKER»
//
// Måneden, begge tallene, at ingen regnskapsdata eller importer endres,
// og at bare utkast kan skrives om. «Er du sikker?» er et spørsmål ingen
// kan svare informert på.
// =====================================================================

export function Byggknapp({ maaned, forventet, eksisterende }: {
  /**
   * Nyeste KOMPLETTE datamåned, fra `v_kurs_maanedstall.linjer_lest`.
   *
   * Serveren slår den opp på nytt før den bygger — feltet her kan bare
   * gi et nei, aldri styre hvilken måned som skrives om.
   */
  maaned: string
  /** Hvor mange aktive stasjoner grunnlaget forventer. */
  forventet: number
  /** Hvor mange planer måneden allerede har. */
  eksisterende: number
}) {
  const mnd = `${maanedsnavn(maaned)} ${maaned.slice(0, 4)}`
  const st = (n: number) => `${n} ${n === 1 ? 'stasjon' : 'stasjoner'}`
  const mangler = forventet - eksisterende

  return (
    <section>
      <h2>Bygg {mnd} på nytt</h2>
      <Forklaring>
        {mnd} er den nyeste måneden der alle stasjonene har regnskapsdata.
        Grunnlaget forventer {st(forventet)}, og {eksisterende} av dem har
        en plan fra før{mangler > 0 ? ` — ${st(mangler)} mangler` : ''}.
      </Forklaring>
      <Forklaring>
        Planene bygges på nytt av tallene som allerede ligger i basen.
        Ingen fil lastes opp, ingen import kjøres, og verken regnskapet,
        svinnet, bilagene, budsjettene eller satsene endres. Bare utkast
        skrives om — en plan du har sluppet, sendt eller avvist står urørt,
        og navngis i svaret.
      </Forklaring>
      <div className="knapperad">
        <HandlingKnapp
          handling={byggPlanerPaaNytt}
          felt={{ maaned }}
          merke={`Bygg ${mnd} på nytt`}
          hva={`månedsplanene for ${mnd}`}
          arbeider="Bygger …"
          variant="primar"
          sporsmaal={
            `Bygge månedsplanene for ${mnd} på nytt?\n\n`
            + `• Grunnlaget forventer ${st(forventet)}. `
            + `${eksisterende} har en plan fra før.\n`
            + `• Gjelder bare ${mnd} — ingen andre måneder.\n`
            + '• Ingen regnskapsdata, svinndata, bilag, budsjetter eller '
            + 'importer endres.\n'
            + '• Bare utkast skrives om. Sluppet, sendt og avvist står urørt.'
          }
        />
      </div>
    </section>
  )
}
