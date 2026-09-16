import Link from 'next/link'
import { kr, manedAar } from '@/lib/format'
import { Datatabell, Forklaring } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import type { A1Kort } from '@/lib/lonnskost/a1-kort'
import {
  KILDEMANGEL, UPRISET_GRUNN, FORBEHOLD_KORT,
  beloepsledetekst, statusforklaring,
} from '@/lib/lonnskost/a1-sprak'

// =====================================================================
// HVA ARBEIDET PÅ DENNE STASJONEN KOSTER — A1
//
// Den andre sannheten på /lonnskost. Den eksisterende økonomiblokken
// viser BOKFØRT lønn; denne viser hva easy@works egne observasjoner av
// arbeidstid og satser faktisk koster på konto 503.
//
// DE BLIR ALDRI ETT TALL. De svarer på forskjellige spørsmål, og et
// gjennomsnitt av dem ville vært et tall ingen kan gjøre noe med.
//
// ---------------------------------------------------------------------
// ALT HER ER VISNING
//
// Ingen beregning, ingen kildeutledning, ingen filtrering. `A1Kort` er
// ferdig regnet av serveren, og kortet bærer allerede den strukturelle
// sikkerheten: `kildemangel` HAR IKKE et kronefelt. Blokka kan derfor
// ikke vise «0 kr» for en måned uten kilde — ikke fordi den husker å
// la være, men fordi tallet ikke finnes å vise.
//
// ---------------------------------------------------------------------
// HANDLING FØR PROSENT
//
// Rekkefølgen er låst av en test:
//
//   1  Minst 143 889 kr
//   2  68,0 timer mangler satsgrunnlag · 1 ansatt   [se vaktene]
//   3  630,8 av 698,8 betalte timer priset (90,3 %)
//   4  4 758 kr med sats fra en annen stasjon
//   5  forbeholdet
//
// Prosenten er nyttig, men den er ikke handlingen. Butikksjefen skal
// først forstå hva tallet er og hva som mangler — så detaljene.
//
// ---------------------------------------------------------------------
// ORDET «KOMPLETT» STÅR IKKE NOE STED
//
// Statusen betyr komplett FOR A1-MODELLEN. Overtid er fortsatt utenfor,
// så ordet ville vært sant om modellen og usant om lønna. Forbeholdet
// står derfor synlig uansett status — også når alt lot seg prise.
// =====================================================================

const timer = new Intl.NumberFormat('nb-NO', {
  minimumFractionDigits: 1, maximumFractionDigits: 1,
})

function Maanedsrad({ kort, stasjonId }: { kort: A1Kort; stasjonId: string }) {
  const maaned = manedAar.format(new Date(`${kort.maaned}-01`))

  if (kort.status === 'kildemangel') {
    return (
      <tr>
        <td>{maaned}</td>
        {/* INGEN KRONEVERDI. Ikke «0 kr», ikke en tankestrek som kan
            forveksles med null — en setning om hva som mangler. */}
        <td colSpan={2}>
          <Status nivaa="handling">Kan ikke beregnes</Status>
          {' '}
          {KILDEMANGEL[kort.mangler]}
          {kort.timer !== undefined && kort.timer > 0 && (
            <>
              {'. '}
              {timer.format(kort.timer)}
              {' kjente timer venter på satsgrunnlag'}
              {kort.personer ? `, ${kort.personer} ansatte` : ''}
              {'.'}
            </>
          )}
        </td>
      </tr>
    )
  }

  const upriset = kort.uprisetePersoner
  return (
    <tr>
      <td>{maaned}</td>
      <td>
        {/* 1. TALLET, med ledeteksten som er en del av det. */}
        <strong>{`${beloepsledetekst(kort.status)} ${kr.format(kort.kroner)}`}</strong>
        <br />
        <span className="undertittel">{statusforklaring(kort.status)}</span>
      </td>
      <td>
        {/* 2. HVA SOM MANGLER — før prosenten. */}
        {upriset.length > 0 && (
          <>
            <Status nivaa="endring">
              {`${timer.format(kort.upriseteTimer)} timer mangler satsgrunnlag`}
            </Status>
            {` · ${upriset.length} ${upriset.length === 1 ? 'ansatt' : 'ansatte'}`}
          </>
        )}

        {/* REVISJONSSPORET, IKKE BARE HANDLINGEN.
            Lenka sto tidligere inne i mangelblokka over, og forsvant
            derfor i det siste uprisede minuttet ble forklart. Da Stig
            ble klassifisert som fastlønnet, ble Bønes august `komplett`
            og de 68 timene ble uoppnåelige — nettopp de timene A1
            BEVISST har valgt å ikke timeprise, og som derfor er de mest
            verdt å kunne ettergå.
            Regelen er knyttet til ARBEIDET, ikke til intern status:
            finnes det upriset ELLER forklart arbeid, skal det kunne
            ettergås. Er alt ordinært priset, er det ingenting å spørre
            om, og lenka skal vekk. */}
        {(kort.upriseteTimer > 0 || kort.forklarteTimer > 0) && (
          <>
            {upriset.length > 0 && ' '}
            <Link href={`/lonnskost/arbeidssted?stasjon=${stasjonId}&maned=${kort.maaned}`}>
              Se vaktene
            </Link>
          </>
        )}
        {(upriset.length > 0 || kort.forklarteTimer > 0) && <br />}

        {/* 3. Dekningen. Prosenten står her, aldri først. */}
        {`${timer.format(kort.prisedeTimer)} av ${timer.format(kort.betalteTimer)} `}
        {'betalte timer priset'}
        {kort.andelPriset !== null && ` (${timer.format(kort.andelPriset)} %)`}

        {/* 4. Innlånt sats — en delmengde, aldri et tillegg. */}
        {kort.innlaantKr > 0 && (
          <>
            <br />
            {`${kr.format(kort.innlaantKr)} av beløpet gjelder `}
            {`${kort.innlaanteNr.length} ${kort.innlaanteNr.length === 1 ? 'ansatt' : 'ansatte'} `}
            {'med sats hentet fra en annen stasjon'}
          </>
        )}

        {/* Forklart arbeid sies høyt. Aldri «0 kr». */}
        {kort.forklarteTimer > 0 && (
          <>
            <br />
            {`${timer.format(kort.forklarteTimer)} timer er forklart og ikke timepriset`}
          </>
        )}

        {/* DATAKVALITET er en ANNEN akse enn økonomisk usikkerhet. */}
        {(kort.dataavvik.dubletter > 0 || kort.dataavvik.avvisteVakter > 0) && (
          <>
            <br />
            <span className="undertittel">
              {'Datakvalitet: '}
              {kort.dataavvik.dubletter > 0
                && `${kort.dataavvik.dubletter} vakt(er) registrert to ganger`}
              {kort.dataavvik.dubletter > 0 && kort.dataavvik.avvisteVakter > 0 && ', '}
              {kort.dataavvik.avvisteVakter > 0
                && `${kort.dataavvik.avvisteVakter} vakt(er) kunne ikke leses`}
            </span>
          </>
        )}
      </td>
    </tr>
  )
}

export function Arbeidsstedsblokk({
  kort, stasjonId,
}: {
  kort: A1Kort[]
  stasjonId: string
}) {
  if (kort.length === 0) return null

  // Forbeholdet fra motoren, ordrett. Flaten finner det ikke selv.
  const forbehold = kort.find((k) => k.status !== 'kildemangel')?.forbehold ?? []
  // Er 1410 ikke utløst i noen av månedene, sier vi det — ellers ser
  // forbeholdet større ut enn det er.
  const ingen1410 = kort.every(
    (k) => k.status === 'kildemangel' || k.helligdagstimer === 0,
  )

  return (
    <Datatabell tittel="Arbeidet på denne stasjonen — konto 503" antall={kort.length}>
      <thead>
        <tr>
          <th>Måned</th>
          <th>Beløp</th>
          <th>Grunnlag</th>
        </tr>
      </thead>
      <tbody>
        {kort.map((k) => (
          <Maanedsrad key={k.maaned} kort={k} stasjonId={stasjonId} />
        ))}
        <tr>
          {/* 5. FORBEHOLDET, uansett status. */}
          <td colSpan={3}>
            <span className="undertittel">{FORBEHOLD_KORT}</span>
            {' '}
            <Forklaring sporsmaal="Hva betyr det?">
              {forbehold.map((f) => <p key={f}>{f}</p>)}
              {ingen1410 && (
                <p>
                  {'Ingen av månedene over inneholder en helligdag, så '}
                  {'helligdagstillegget påvirker ikke tallene her.'}
                </p>
              )}
            </Forklaring>
          </td>
        </tr>
      </tbody>
    </Datatabell>
  )
}

/** Årsakene, til drilldownsiden. Eksportert her så teksten bor ett sted. */
export const AARSAKSTEKST = UPRISET_GRUNN
