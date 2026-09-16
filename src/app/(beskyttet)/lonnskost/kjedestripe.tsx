import Link from 'next/link'
import { kr, manedAar } from '@/lib/format'
import { Datatabell } from '@/components/ui/side'
import { Status } from '@/components/ui/status'
import { kjedesumtekst, type Kjede, type Kjederad } from '@/lib/lonnskost/a1-kjede'
import { KILDEMANGEL, beloepsledetekst } from '@/lib/lonnskost/a1-sprak'

// =====================================================================
// LEDEROVERSIKT OVER STASJONENE — IKKE FEM KOPIER AV B2e.1
//
// Ett spørsmål, besvart på to sekunder: hvor står kjeden, og hvor
// ligger problemet? Stasjonsbildet ligger ett klikk unna.
//
// ---------------------------------------------------------------------
// HANDLING FØR PROSENT, OG PROSENTEN ER IKKE HER I DET HELE TATT
//
// Dekningsgraden per stasjon hører til stasjonsbildet. Her er det bare
// tre ting som betyr noe: mangler grunnlag, har upriset arbeid, ferdig.
// Radene står i den rekkefølgen — aldri etter kronebeløp, som ville
// gjort den dyreste stasjonen til den viktigste.
//
// ---------------------------------------------------------------------
// FORKLARTE TIMER ER INFORMASJON, IKKE STATUS
//
// Bønes har 68 forklarte timer. De gjør ikke raden gul og flytter den
// ikke opp — men «Beregnet 143 889 kr» alene kan leses som «alle timer
// er priset», og det er usant. Derfor står de diskret, bak et punktum.
//
// ---------------------------------------------------------------------
// INGEN FASTLØNNSLOGIKK
//
// Fila konsumerer `A1Kort`. Den vet ikke at fastlønn finnes.
// =====================================================================

const timer = new Intl.NumberFormat('nb-NO', {
  minimumFractionDigits: 1, maximumFractionDigits: 1,
})

function Rad({ rad, maaned }: { rad: Kjederad; maaned: string }) {
  const k = rad.kort
  const drilldown = `/lonnskost/arbeidssted?stasjon=${rad.id}&maned=${maaned}`

  if (k.status === 'kildemangel') {
    return (
      <tr>
        <td>
          <Link href={`/lonnskost?stasjon=${rad.id}`}>
            {`${rad.butikknummer} ${rad.navn}`}
          </Link>
        </td>
        <td>
          <Status nivaa="endring">{KILDEMANGEL[k.mangler]}</Status>
          {/* Timene er kjent naar registeret mangler - de skal sies, ellers
              ser en stasjon med 129 timers arbeid ut som en tom stasjon. */}
          {k.timer !== undefined && k.personer !== undefined && (
            ` · ${k.personer} personer, ${timer.format(k.timer)} t`
          )}
        </td>
        <td><Link href="/import">Last opp</Link></td>
      </tr>
    )
  }

  return (
    <tr>
      <td>
        <Link href={`/lonnskost?stasjon=${rad.id}`}>
          {`${rad.butikknummer} ${rad.navn}`}
        </Link>
      </td>
      <td>
        {`${beloepsledetekst(k.status)} ${kr.format(k.kroner)}`}
        {k.upriseteTimer > 0 && (
          <>
            {' · '}
            <Status nivaa="endring">
              {`${timer.format(k.upriseteTimer)} timer mangler satsgrunnlag`}
            </Status>
          </>
        )}
        {/* INFORMASJON, ikke status. Ingen Status-komponent, ingen farge. */}
        {k.forklarteTimer > 0 && ` · ${timer.format(k.forklarteTimer)} t forklart`}
      </td>
      <td>
        {(k.upriseteTimer > 0 || k.forklarteTimer > 0) && (
          <Link href={drilldown}>Se vaktene</Link>
        )}
      </td>
    </tr>
  )
}

export function Kjedestripe({ kjede }: { kjede: Kjede }) {
  // INGEN MAANED = ingen autorisert stasjon har en eneste kilde. Da er
  // det ingenting aa vise en periode for, og en stripe uten maaned ville
  // vaert en overskrift uten innhold.
  if (kjede.maaned === null) return null

  const t = kjedesumtekst(kjede.sum, kjede.maaned)

  return (
    <section className="kort">
      <h2>{`Arbeidet på stasjonene — konto 503 · ${manedAar.format(new Date(`${kjede.maaned}-01`))}`}</h2>

      <p><strong>{t.hoved}</strong></p>
      {t.tillegg && <p className="undertittel">{t.tillegg}</p>}

      <Datatabell tittel="Per stasjon" antall={kjede.rader.length}>
        <thead>
          <tr>
            <th>Stasjon</th>
            <th>Konto 503</th>
            <th>Neste steg</th>
          </tr>
        </thead>
        <tbody>
          {kjede.rader.map((r) => (
            <Rad key={r.id} rad={r} maaned={kjede.maaned!} />
          ))}
        </tbody>
      </Datatabell>
    </section>
  )
}
