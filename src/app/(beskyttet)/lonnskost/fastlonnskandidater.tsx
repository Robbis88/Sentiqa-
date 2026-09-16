import { LonnsformVelger } from '../lonn/lonnsform-velger'
import { Datatabell } from '@/components/ui/side'
import type { A1Kort } from '@/lib/lonnskost/a1-kort'

// =====================================================================
// DE SOM ARBEIDET, MEN SOM LØNNSFILA IKKE KJENNER
//
// Stig er butikksjef på Bønes. Han stempler — 10 vakter og 68,0 timer i
// august 2026 — men står ikke i easy@work-eksporten, fordi den bare
// bærer timelønnede. A1 kan derfor ikke koble nummeret hans, og timene
// hans havnet som «mangler satsgrunnlag … det faktiske beløpet er
// høyere». Begge deler er usant: lønna hans føres på konto 501, og 503
// vokser aldri med de timene.
//
// ---------------------------------------------------------------------
// HVORFOR LØNNSFORM-BLOKKA IKKE RAKK HAM
//
// Den bygges av `v_lonnsart_ansatt_maaned`, altså lønnsfila. Sandra på
// Lone kunne merkes fordi hun STO der (feilaktig som timelønn). Stig
// står ikke der i det hele tatt, og lista kunne dermed ikke tilby ham.
// To lister, samme felt: `ansatt_avtale.lonnsform`, nådd fra de to
// stedene spørsmålet faktisk oppstår.
//
// ---------------------------------------------------------------------
// KANDIDATENE KOMMER FRA MOTOREN, IKKE FRA EN SQL VED SIDEN AV
//
// Kun `grunn === 'ukjent_nummer'` — samme populasjon som motorens
// `uslaatteNumre`. Det er ikke en detalj:
//
//   «mangler i eget register» ville tatt med Carmen og Julian, som er
//   INNLÅNT fra Lone og prises helt korrekt gjennom kryssoppslaget. Å
//   tilby dem som fastlønnskandidater ville invitert til å skjule ekte
//   lønnskost.
//
//   `motstrid` ville sluppet en navnekonflikt inn bakveien. En avtale
//   skal ikke kunne kjøpe fri et navn-veto — og motoren honorerer den
//   heller ikke der, se `a1.ts`.
//
// ---------------------------------------------------------------------
// INGEN ANTAKELSE, NOEN GANG
//
// At nummeret mangler i registeret gjør det IKKE til fastlønn. Det er
// like ofte et ekte datahull. Derfor er dette en LISTE Å TA STILLING
// TIL, ikke en regel som går av seg selv: valget settes av et menneske,
// per person, og `null` forblir uavklart.
// =====================================================================

type Kandidat = { ansattNr: string; navn: string; timer: number; maaneder: string[] }

/** Uslåtte numre på tvers av månedene, med timene samlet. */
export function kandidater(kort: A1Kort[]): Kandidat[] {
  const per = new Map<string, Kandidat>()
  for (const k of kort) {
    if (k.status === 'kildemangel') continue
    for (const p of k.uprisetePersoner) {
      // KUN ukjent_nummer. Se hodet.
      if (p.grunn !== 'ukjent_nummer') continue
      const f = per.get(p.ansattNr)
        ?? { ansattNr: p.ansattNr, navn: p.navn, timer: 0, maaneder: [] }
      f.timer = Math.round((f.timer + p.timer) * 100) / 100
      if (!f.maaneder.includes(k.maaned)) f.maaneder.push(k.maaned)
      per.set(p.ansattNr, f)
    }
  }
  // Flest timer først: der står mest på spill.
  return [...per.values()].sort((a, b) => b.timer - a.timer)
}

export function Fastlonnskandidater(
  { kort, stasjonId }: { kort: A1Kort[]; stasjonId: string },
) {
  const liste = kandidater(kort)
  if (liste.length === 0) return null

  return (
    <section className="kort">
      <h2>Arbeidet her, men ikke i lønnsfila</h2>
      <p className="undertittel">
        {'Disse stemplet, men easy@work-eksporten kjenner ikke nummeret. '}
        {'Er en av dem fastlønnet, telles timene som arbeidstid og prises ikke. '}
        {'La feltet stå tomt om du er usikker — uavklart er ikke det samme som fastlønn.'}
      </p>

      <Datatabell tittel="Uten lønnsgrunnlag" antall={liste.length}>
        <thead>
          <tr>
            <th>Ansatt</th>
            <th>Måned</th>
            <th>Timer</th>
            <th>Lønnsform</th>
          </tr>
        </thead>
        <tbody>
          {liste.map((k) => (
            <tr key={k.ansattNr}>
              <td>{`${k.ansattNr} · ${k.navn}`}</td>
              <td>{k.maaneder.join(', ')}</td>
              <td className="tall">{k.timer.toFixed(1).replace('.', ',')}</td>
              <td>
                {/* SAMME handling og velger som /lonn og Lønnsform-blokka.
                    Tre innganger, ett felt - ikke tre sannheter. `verdi`
                    er alltid null her: en kandidat er per definisjon en
                    som ikke er klassifisert ennaa. */}
                <LonnsformVelger
                  stasjonId={stasjonId}
                  ansattNr={k.ansattNr}
                  navn={k.navn}
                  verdi={null}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </Datatabell>
    </section>
  )
}
