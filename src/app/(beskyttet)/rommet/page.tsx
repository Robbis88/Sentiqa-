import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { kr, tall } from '@/lib/format'
import { Sidehode, Tomtilstand, Nokkeltall, Datatabell, Forklaring } from '@/components/ui/side'
import { Sideramme } from '@/components/ui/sideramme'
import {
  finnSparefunn, omfang,
  type Bilagsrad, type Omsetningsrad, type Stasjon,
} from '@/lib/rommet/spare'
import { DRIFT_BEGREP } from '@/lib/kurs/loftestenger'

// =====================================================================
// REGNSKAPSROMMET — HVOR DET FAKTISK ER PENGER
// =====================================================================
//
// Robert 2026-09-12: «lag en live demo med ekte tall der vi får bedre
// kostnadkontroll».
//
// Grunnlaget er `bilagssum`: tolv måneders leverandørdetalj som følger
// hver regnskapsfil. Den lå på NULL rader i produksjon til i dag, fordi
// steget bare fantes i den ene av importens to veier.
//
// ---------------------------------------------------------------------
// HVORFOR DENNE SIDA ER EIERENS ALENE
//
// Den sammenligner stasjoner med navn, per leverandør. Det er en
// eierbeslutning å ringe ASKO og be om samme pris som Varden har — og en
// butikksjef som ser at hennes stasjon er dyrest på en avtale hun ikke
// har forhandlet, har fått et tall uten en handling.
//
// Månedsplanen er den andre enden: der får butikksjefen ÉN ting, og bare
// det hun rår over.
// ---------------------------------------------------------------------

export const metadata = { title: 'Regnskapsrommet · Sentiqa' }

export default async function Side() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') {
    return (
      <Sideramme>
        <Sidehode tittel="Regnskapsrommet" />
        <Tomtilstand
          tittel="Denne siden er eierens"
          forklaring={
            'Den sammenligner stasjoner med navn, per leverandør. Din egen '
            + 'månedsplan finner du under Månedsplan — der står den ene '
            + 'tingen som betyr mest denne måneden.'
          }
        />
      </Sideramme>
    )
  }

  const supabase = await lagSupabaseServerKlient()

  const { data: stasjonsrader } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .eq('retailer_id', bruker.retailerId)
    .is('slettet_tid', null)
    .order('butikknummer')
    .limit(200)
  const stasjoner = (stasjonsrader ?? []) as Stasjon[]

  // =================================================================
  // FOR EN RANGERT LISTE ER EN GRENSE ET VALG, IKKE EN RISIKO
  // =================================================================
  //
  // Viewet (0207) gir 1 848 rader for Kelsar - 757 ulike tekster, fordi
  // `tekst` ogsaa inneholder fakturanumre og «Inngaaende faktura». Det
  // er nettopp det `erLeverandor` kaster ut etterpaa, saa foerste utgave
  // hentet en haug med rader for aa forkaste dem, traff taket og krasjet.
  //
  // Feilen i tenkningen var aa behandle dette som en sum. Faren
  // `maaVaereHele` finnes for er en USORTERT spoerring brukt til en
  // SUM - da ser et avkortet svar ut som ekte tall. Her leter vi etter
  // de STOERSTE forskjellene, og da er rekkefoelgen halve svaret:
  //
  //   - bare begrepene som kan sammenlignes (`DRIFT_BEGREP`)
  //   - bare beloep over 1 000 kr: en leverandoervavtale verdt aa ringe om
  //     er ikke to hundre kroner
  //   - stoerste foerst, og vi SIER det hvis vi traff grensen
  //
  // Listene bor fortsatt ett sted - de sendes som filter, ikke gjentas
  // i viewet.
  const MATERIELT_KR = 1000
  const takBilag = 600
  const takMaaned = Math.max(1, stasjoner.length) * 13

  const [bilagsvar, omssvar] = await Promise.all([
    supabase.from('v_rommet_leverandor')
      .select('stasjon_id, begrep, tekst, belop_kr, antall, maaneder, eldste, nyeste')
      .eq('retailer_id', bruker.retailerId)
      .in('begrep', [...DRIFT_BEGREP])
      .gte('belop_kr', MATERIELT_KR)
      .order('belop_kr', { ascending: false })
      .limit(takBilag),
    supabase.from('v_kurs_maanedstall')
      .select('stasjon_id, maaned, omsetning_kr')
      .eq('retailer_id', bruker.retailerId)
      .limit(takMaaned),
  ])

  const bilag = (bilagsvar.data ?? []) as unknown as Bilagsrad[]
  const avkortet = bilag.length >= takBilag

  // OMSETNINGEN ER NEVNEREN, og den maa vaere HEL. En avkortet omsetning
  // gir for hoey andel paa hver stasjon, og da er hele sammenligningen
  // feil - uten at noe sier fra. Her er `maaVaereHele` paa sin plass.
  let oms: Omsetningsrad[]
  try {
    oms = maaVaereHele(omssvar, 'omsetningen', takMaaned) as unknown as Omsetningsrad[]
  } catch (e) {
    return (
      <Sideramme>
        <Sidehode tittel="Regnskapsrommet" />
        <Tomtilstand
          tittel="Grunnlaget kunne ikke leses helt"
          forklaring={
            `${e instanceof Error ? e.message : String(e)} `
            + 'Tallene vises ikke, fordi omsetningen er nevneren i hver '
            + 'sammenligning — en avkortet nevner ville gitt for høy andel på '
            + 'hver stasjon, uten at noe sa fra.'
          }
        />
      </Sideramme>
    )
  }

  if (bilag.length === 0) {
    return (
      <Sideramme>
        <Sidehode tittel="Regnskapsrommet" />
        <Tomtilstand
          tittel="Ingen bilagsdetalj ennå"
          forklaring={
            'Tolv måneders leverandørdetalj følger hver regnskapsfil — den '
            + 'ligger i Kostnader-fanen, som er en pivottabell og bærer en '
            + 'kopi av kildedataene sine. Last opp en regnskapsrapport, så '
            + 'fylles denne siden.'
          }
        />
      </Sideramme>
    )
  }

  const o = omfang(bilag)
  const funn = finnSparefunn(bilag, oms, stasjoner)
  const sumAar = funn.reduce((a, f) => a + (f.aarligKr ?? 0), 0)
  const pst = (n: number) => `${(n * 100).toFixed(2).replace('.', ',')} %`

  return (
    <Sideramme>
      <Sidehode
        tittel="Regnskapsrommet"
        undertittel={
          sumAar > 0
            ? `${kr.format(Math.round(sumAar))} i året er forskjellen mellom stasjonene`
            : 'Leverandørene dine, sammenlignet mellom stasjonene'
        }
      />

      <Nokkeltall
        merkelapp="Forskjellen mellom stasjonene, per år"
        verdi={kr.format(Math.round(sumAar))}
        sammenlignet={`${funn.length} leverandører · ${o.maaneder} måneder · ${tall.format(o.linjer)} bilagslinjer`}
        retning={sumAar > 0 ? 'opp' : 'flat'}
      />

      <Forklaring>
        <p>
          Hver leverandør, summert per stasjon og delt på stasjonens omsetning.
          Stasjonen med lavest andel er målestokken — ikke et mål, men et bevis
          på at prisen finnes.
        </p>
        <p>
          Det grupperes på <strong>leverandør</strong>, ikke på konto.{' '}
          <em>627 Renhold</em> og <em>633 Forbruksmateriell</em> er to kontoer og
          samme leverandør; hver linje ser rimelig ut alene. Kontoen er hvor
          regnskapsføreren la beløpet, leverandøren er hvem du kan ringe.
        </p>
        <p>
          Vaskemaskinen er holdt utenfor. <em>630 Leie</em> og{' '}
          <em>634 Rep &amp; vedlikehold</em> følger maskinen, og Dale har ingen
          vask — Dale ville alltid vært «billigst», og en naiv sammenligning ber
          deg jage 1,6 millioner som ikke finnes. Telefon og forsikring er like
          mange kroner på hver stasjon; der oppstår forskjellen bare fordi vi
          deler på omsetning.
        </p>
        <p>
          Bare beløp over {kr.format(MATERIELT_KR)} er med, og bare de
          begrepene der en forskjell mellom to stasjoner betyr noe. En
          leverandøravtale verdt å ringe om er ikke to hundre kroner.
          {avkortet && (
            <>
              {' '}Lista viser de {takBilag} største — det finnes flere under
              dem.
            </>
          )}
        </p>
        <p>
          Grunnlaget dekker {o.eldste} til {o.nyeste}.{' '}
          {o.utenNavn > 0 && (
            <>
              {tall.format(o.utenNavn)} linjer har ingen leverandør å ringe
              («Inngående faktura», fakturanummer, periodetekster) og er utenfor
              sammenligningen, men ikke slettet.
            </>
          )}
        </p>
      </Forklaring>

      <Datatabell
        tittel="Leverandører, sortert på hva forskjellen er verdt"
        antall={funn.length}
        tom="Ingen leverandør finnes på mer enn én stasjon ennå."
      >
        <thead>
          <tr>
            <th scope="col">Leverandør</th>
            <th scope="col">Konti</th>
            <th scope="col">Dyreste</th>
            <th scope="col">Laveste</th>
            <th scope="col">Per år</th>
          </tr>
        </thead>
        <tbody>
          {funn.slice(0, 25).map((f) => {
            const dyrest = f.per.find((p) => p.andel != null)
            return (
              <tr key={f.leverandor}>
                <td>{f.leverandor}</td>
                <td>{f.begreper.length}</td>
                <td>
                  {dyrest?.andel != null
                    ? `${dyrest.navn} · ${pst(dyrest.andel)}`
                    : '—'}
                </td>
                <td>
                  {f.beste ? `${f.beste.navn} · ${pst(f.beste.andel)}` : '—'}
                </td>
                <td>{f.aarligKr != null ? kr.format(Math.round(f.aarligKr)) : '—'}</td>
              </tr>
            )
          })}
        </tbody>
      </Datatabell>

      {funn.slice(0, 6).map((f) => (
        <Datatabell
          key={f.leverandor}
          tittel={f.leverandor}
          antall={f.per.length}
        >
          <thead>
            <tr>
              <th scope="col">Stasjon</th>
              <th scope="col">Kroner</th>
              <th scope="col">Av omsetning</th>
              <th scope="col">Bilag</th>
            </tr>
          </thead>
          <tbody>
            {f.per.map((p) => (
              <tr key={p.stasjonId}>
                <td>{p.navn}</td>
                <td>{kr.format(Math.round(p.kroner))}</td>
                <td>{p.andel != null ? pst(p.andel) : '—'}</td>
                <td>{tall.format(p.bilag)}</td>
              </tr>
            ))}
          </tbody>
        </Datatabell>
      ))}
    </Sideramme>
  )
}
