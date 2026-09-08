'use client'
import { useKvittering } from '@/components/ui/kvittering'
import { Knapp } from '@/components/ui/knapp'
import { Felt } from '@/components/ui/felt'
import type { Kvittering } from '@/lib/kvittering'
import { kr } from '@/lib/format'
import { BILVASK_BRUTTOANDEL } from '@/lib/lonnskost/bilvask'
import { lagreBilvask, lagreFastlonn } from './handlinger'

// =====================================================================
// TALLENE INGEN FIL LEVERER
//
// Alt annet på denne siden kommer av en opplasting. Disse to gjør ikke
// det, og de gjør bruttofortjenesten feil så lenge de mangler:
//
//   bilvask    abonnementene betales rett til konto, så kassa ser dem
//              aldri. Rapporten kommer på e-post, én gang i uka.
//   fastlønn   BP-en fører kjedesnittet, og regnskapets konto 501
//              finnes først når måneden er avlagt.
//
// KLIENTKOMPONENT FORDI SVARET ER POENGET. Legger to personer inn samme
// uke, er det den andre som skal få vite det — «uke 35 finnes allerede»
// er hele grunnen til at nøkkelen er unik. Et rent `<form action=…>` har
// ingen plass å vise den setningen.
//
// SKJEMAET STÅR NEDERST PÅ SIDEN, ikke øverst. Det brukes én gang i uka;
// tallene over leses hver dag.
// =====================================================================

export function ManuelleTall({
  stasjonId,
  erAdmin,
  aar,
  uke,
  maaned,
  uker,
  maaneder,
}: {
  stasjonId: string
  erAdmin: boolean
  aar: number
  uke: number
  maaned: number
  uker: { ar: number; uke: number; belopKr: number; iRegnskapet: 'ja' | 'nei' | 'delvis' }[]
  maaneder: { ar: number; maned: number; grunnlonnKr: number }[]
}) {
  const [vaskSvar, vaskKjor, vaskVenter] =
    useKvittering<Kvittering, FormData>(lagreBilvask, undefined)
  const [lonnSvar, lonnKjor, lonnVenter] =
    useKvittering<Kvittering, FormData>(lagreFastlonn, undefined)

  return (
    <div className="sq-manuelle-tall">
      <form action={vaskKjor} className="sq-skjema">
        <input type="hidden" name="stasjon" value={stasjonId} />
        <h3>Bilvask · abonnement</h3>
        <p className="undertittel">
          {'Beløpet fra ukesrapporten på e-post. Kassa ser ikke abonnementene — '}
          {'75 % av beløpet regnes som bruttofortjeneste. En uke som krysser '}
          {'månedsskiftet deles på sju og fordeles per dag.'}
        </p>
        {/* AARET STAAR SOM FELT, ikke skjult. Legger man inn en uke i
            januar for aaret som gikk, er det aaret som er poenget - og et
            skjult felt ville stille lagt den paa feil aar. */}
        <Felt etikett="År" name="ar" type="number" defaultValue={String(aar)} required />
        <Felt etikett="Uke" name="uke" type="number" defaultValue={String(uke)} required />
        <Felt etikett="Beløp for uka" name="belop" inputMode="decimal" required />
        <Knapp type="submit" disabled={vaskVenter}>
          {vaskVenter ? 'Lagrer …' : 'Lagre uke'}
        </Knapp>
        {vaskSvar?.feil && <p className="sq-slett-feil" role="alert">{vaskSvar.feil}</p>}
        {vaskSvar?.ok && <p className="sq-slett-ok" role="status">{vaskSvar.ok}</p>}

        {/* ===============================================================
            EN UNIK NOEKKEL UTEN EN OVERSIKT LOESER HALVE PROBLEMET
            ===============================================================
            Noekkelen hindrer at samme uke foeres to ganger. Men uten en
            liste kan ingen bekrefte at uka KOM INN - eller oppdage at
            noen alt hadde lagt den inn. Da er den andre halvparten av
            problemet fortsatt der, bare usynlig.
            Nyeste foerst: den uka man nettopp la inn skal staa oeverst. */}
        {uker.length > 0 && (
          <ul className="sq-lagt-inn">
            {uker.slice(0, 8).map((u) => (
              <li key={`${u.ar}-${u.uke}`}>
                <span>{`Uke ${u.uke} · ${u.ar}`}</span>
                <span className="num">{`${kr.format(Math.round(u.belopKr))}`}</span>
                {/* HVA UKA GJOER, IKKE BARE AT DEN FINNES.
                    Er maaneden avlagt, har regnskapet alt disse kronene,
                    og bidraget holdes utenfor for aa unngaa
                    dobbelfoering. Da flytter uka ingenting - og uten
                    denne linja ser det ut som at den ikke kom inn. Neste
                    steg er at noen legger den inn en gang til. */}
                <span className="undertittel">
                  {u.iRegnskapet === 'ja'
                    ? 'ligger allerede i regnskapet for måneden'
                    : `brutto ${kr.format(Math.round(u.belopKr * BILVASK_BRUTTOANDEL))}`
                      + (u.iRegnskapet === 'delvis'
                        ? ' — bare den delen som faller i en måned regnskapet '
                          + 'ikke har svart på ennå'
                        : '')}
                </span>
              </li>
            ))}
          </ul>
        )}
        {uker.length === 0 && (
          <p className="undertittel">Ingen uker lagt inn ennå.</p>
        )}
      </form>

      {/* EIERENS ALENE. Raden peker paa én navngitt person - stasjonen har
          én butikksjef - og butikksjefen ble stengt ute fra konto 501
          nettopp fordi den raden var én persons loenn. Skjemaet vises
          derfor ikke i det hele tatt for andre; policyen i 0185 er den
          som faktisk haandhever det. */}
      {erAdmin && (
        <form action={lonnKjor} className="sq-skjema">
          <input type="hidden" name="stasjon" value={stasjonId} />
          <h3>Butikksjefens grunnlønn</h3>
          <p className="undertittel">
            {'Grunnlønn før påslag. Feriepenger, arbeidsgiveravgift og pensjon '}
            {'regnes av den. Brukes bare for måneder regnskapet ennå ikke har '}
            {'svart på — konto 501 vinner alltid når den finnes.'}
          </p>
          <Felt etikett="År" name="ar" type="number" defaultValue={String(aar)} required />
          <Felt etikett="Måned" name="maned" type="number" defaultValue={String(maaned)} required />
          <Felt etikett="Grunnlønn" name="grunnlonn" inputMode="decimal" required />
          <Knapp type="submit" disabled={lonnVenter}>
            {lonnVenter ? 'Lagrer …' : 'Lagre grunnlønn'}
          </Knapp>
          {lonnSvar?.feil && <p className="sq-slett-feil" role="alert">{lonnSvar.feil}</p>}
          {lonnSvar?.ok && <p className="sq-slett-ok" role="status">{lonnSvar.ok}</p>}

          {maaneder.length > 0 && (
            <ul className="sq-lagt-inn">
              {maaneder.slice(0, 6).map((m) => (
                <li key={`${m.ar}-${m.maned}`}>
                  <span>{`${String(m.maned).padStart(2, '0')} · ${m.ar}`}</span>
                  <span className="num">{kr.format(Math.round(m.grunnlonnKr))}</span>
                </li>
              ))}
            </ul>
          )}
          {maaneder.length === 0 && (
            <p className="undertittel">Ingen måneder lagt inn ennå.</p>
          )}
        </form>
      )}
    </div>
  )
}
