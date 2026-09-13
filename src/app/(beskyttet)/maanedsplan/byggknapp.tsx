import { HandlingKnapp } from '@/components/ui/handling-knapp'
import { Forklaring } from '@/components/ui/side'
import { maanedsnavn } from '@/lib/kurs/plan'
import { byggPlanerPaaNytt } from './handlinger'

// =====================================================================
// «Bygg utkastene på nytt fra eksisterende data»
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
// SPØRSMÅLET SIER HVA SOM SKJER, IKKE «ER DU SIKKER»
//
// Måneden, antallet stasjoner, at ingen regnskapsdata eller importer
// endres, og at bare utkast kan skrives om. «Er du sikker?» er et
// spørsmål ingen kan svare informert på.
// =====================================================================

export function Byggknapp({ maaned, stasjoner }: {
  /** ISO, første i måneden. Serveren slår den opp på nytt før den bygger. */
  maaned: string
  /** Hvor mange planer måneden har. Målt på sida, ikke antatt. */
  stasjoner: number
}) {
  const mnd = `${maanedsnavn(maaned)} ${maaned.slice(0, 4)}`
  const antall = `${stasjoner} ${stasjoner === 1 ? 'stasjon' : 'stasjoner'}`

  return (
    <section>
      <h2>Bygg {mnd} på nytt</h2>
      <Forklaring>
        Planene for {mnd} bygges på nytt av tallene som allerede ligger i
        basen. Ingen fil lastes opp, ingen import kjøres, og verken
        regnskapet, svinnet, bilagene, budsjettene eller satsene endres.
        Bare utkast skrives om — en plan du har sluppet, sendt eller
        avvist står urørt, og navngis i svaret.
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
            + `• Gjelder ${antall} — bare ${mnd}, ingen andre måneder.\n`
            + '• Ingen regnskapsdata, svinndata, bilag, budsjetter eller '
            + 'importer endres.\n'
            + '• Bare utkast skrives om. Sluppet, sendt og avvist står urørt.'
          }
        />
      </div>
    </section>
  )
}
