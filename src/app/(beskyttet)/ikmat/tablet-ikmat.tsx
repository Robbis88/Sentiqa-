import Link from 'next/link'
import { FREKVENS_ETIKETT } from '@/lib/ikmat/standard'

// =====================================================================
// IK-mat på nettbrettet: en kø, ikke et regneark.
//
// DET SOM BLE FUNNET: nettbrettet hadde ALLEREDE en god måleflate —
// `/ikmat/maaling`, som vakta lenker til. Én enhet av gangen, klient-
// side, med strakstiltak i det samme feltet når noe er utenfor kravet.
//
// Og så hadde `/ikmat` — nettbrettets egen menyoppføring — en ANNEN
// måleflate ved siden av: 27 rader i en firekolonners tabell, hver med
// et tekstfelt og en Lagre-knapp som sendte hele sida på nytt. To
// grensesnitt for den samme jobben, og det dårligste sto der hun
// faktisk trykker.
//
// Derfor måler denne sida ikke lenger. Den svarer på nettbrettets
// spørsmål — «hva skal jeg gjøre nå?» — og sender henne inn i flyten
// som allerede finnes. Formen er den samme som IK-mat-radene på vakta,
// fordi det er den formen hun kjenner fra før.
//
// Lederen beholder tabellen. Hennes spørsmål er et annet: hva krever
// oppmerksomhet, og hvorfor — og da er hele rutenettet riktig.
// =====================================================================

export type Gruppe = {
  frekvens: string
  antall: number
  malt: number
  utenfor: number
}

export type Stasjonsgruppe = {
  stasjonId: string
  grupper: Gruppe[]
}

export function TabletIkMat({
  stasjoner,
  ord = {},
}: {
  stasjoner: Stasjonsgruppe[]
  ord?: Record<string, string>
}) {
  const t = (s: string) => ord[s] ?? s
  const alle = stasjoner.flatMap((s) => s.grupper)

  if (alle.length === 0) {
    return (
      <section className="tablet-seksjon">
        <p className="undertittel">{t('Ingen kontrollpunkter satt opp på denne stasjonen.')}</p>
      </section>
    )
  }

  return (
    <>
      {stasjoner.map((s) => (
        <section className="tablet-seksjon" key={s.stasjonId}>
          <ul className="rutine-liste">
            {s.grupper.map((g) => {
              const igjen = g.antall - g.malt
              const ferdig = igjen === 0
              return (
                <li
                  key={`${s.stasjonId}-${g.frekvens}`}
                  className={`ikmat-rutine${ferdig ? ' gjort' : ''}`}
                >
                  {/* Samme kryss som rutinene på vakta. Tomt til alt i
                      gruppen er målt — formen sier hva som gjenstår, og
                      den sier det uten farge. */}
                  <span className={`kryss ${ferdig ? 'av' : ''}`} aria-hidden>{ferdig ? '✓' : ''}</span>
                  <Link
                    href={`/ikmat/maaling?stasjon=${s.stasjonId}&frekvens=${g.frekvens}`}
                    className="rutine-tekst ikmat-lenke"
                  >
                    <strong>{t(FREKVENS_ETIKETT[g.frekvens] ?? g.frekvens)}</strong>
                    <span className="undertittel">
                      {' '}— {g.malt}/{g.antall} {t('målt')}
                      {ferdig ? '' : ` · ${t('trykk for å måle')}`}
                    </span>
                    {/* ET AVVIK ER EN OPPGAVE, IKKE EN KVITTERING. Alt
                        annet på denne sida forsvinner når det er gjort;
                        dette blir stående til noen har rettet det, og
                        det står i ord slik at det ikke kan forsvinne i
                        en farge. */}
                    {g.utenfor > 0 && (
                      <span className="ikmat-utenfor">
                        {g.utenfor} {t('utenfor kravet')}
                      </span>
                    )}
                  </Link>
                </li>
              )
            })}
          </ul>
        </section>
      ))}
    </>
  )
}
