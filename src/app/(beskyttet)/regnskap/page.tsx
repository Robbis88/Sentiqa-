import Link from 'next/link'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, prosent, manedAar, avviksKlasse } from '@/lib/format'
import { hentRegnskapVarsler } from '@/lib/regnskap-varsler'
import { byggPeriodeGrupper } from '@/lib/perioder'
import { RegnskapButikksjef } from './butikksjef-visning'
import { RegnskapVarsler } from './varsler-liste'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { PeriodeVelger } from '../periode-velger'
import { AiKontekst } from '../ai-kontekst'
import { Sidehode, Tomtilstand, Forklaring, Nokkeltall, Datatabell } from '@/components/ui/side'
import { Status, type Statusnivaa } from '@/components/ui/status'
import { motBudsjett, storsteAvvik, svaret, type Driver } from '@/lib/regnskap/mot-budsjett'

type Linje = {
  seksjon: string
  kode: string | null
  post: string
  sortering: number | null
  regnskap: number | null
  budsjett: number | null
  avvik: number | null
  index_pct: number | null
  regnskap_hittil?: number | null
  budsjett_hittil?: number | null
}

const SEKSJON_TITTEL: Record<string, string> = {
  omsetning: 'Omsetning',
  bruttofortjeneste: 'Bruttofortjeneste',
  driftskostnader: 'Driftskostnader',
  resultat: 'Resultat',
}


/**
 * De tre gamle fargeklassene, oversatt til systemets semantiske spraak.
 *
 * Grensene er uendret - det er bare navnet og det at ORDET foelger med
 * som er nytt. En prosentpip der fargen var eneste forskjell mellom
 * «greit» og «ikke greit» kunne ikke leses av den som ikke ser farge.
 */
function nivaaFraKlasse(k: string): Statusnivaa {
  return k === 'gronn' ? 'normal' : k === 'gul' ? 'endring' : k === 'rod' ? 'handling' : 'normal'
}

export default async function RegnskapSide({ searchParams }: { searchParams: Promise<{ periode?: string; butikknummer?: string; stasjon?: string }> }) {
  const bruker = await hentInnloggetBruker()
  const sp = await searchParams

  // Butikksjef får en skjermet visning av EGEN stasjon (kun påvirkbare kostnader).
  if (bruker.rolle === 'butikksjef') {
    return <RegnskapButikksjef bruker={bruker} periode={sp.periode} butikknummer={sp.butikknummer} />
  }
  if (bruker.rolle !== 'retailer_admin') {
    return <p>Kun eier/butikksjef har tilgang til regnskap.</p>
  }

  const supabase = await lagSupabaseServerKlient()

  // Alle perioder (rød tråd) — velg via ?periode=YYYY-MM, ellers siste.
  const { data: perioder } = await supabase
    .from('regnskapslinjer').select('periode').is('stasjon_id', null).order('periode', { ascending: false })
    .overrideTypes<{ periode: string }[]>()
  const liste = [...new Set((perioder ?? []).map((p) => p.periode))]

  if (liste.length === 0) {
    return (
      <>
        <Sidehode tittel="Regnskap" undertittel="Resultatet målt mot budsjettet." />
        <Tomtilstand
          tittel="Ingen regnskapsdata ennå"
          forklaring="Last opp regnskapsrapporten under Import og trykk Behandle, så fylles siden."
          handling={<Link href="/import" className="sq-knapp primar">Gå til Import</Link>}
        />
      </>
    )
  }

  // Periode: enkeltmåned (YYYY-MM) eller hittil i år (YYYY-hittil). År skilles.
  const valgt = sp.periode
  const ytdAar = valgt && /^\d{4}-hittil$/.test(valgt) ? valgt.slice(0, 4) : null
  const hittil = ytdAar != null
  let aktivPeriode: string
  let valgtVerdi: string
  if (hittil) {
    const iAaret = liste.filter((p) => p.slice(0, 4) === ytdAar).sort()
    aktivPeriode = iAaret[iAaret.length - 1] ?? liste[0] // siste mnd i året = full hittil-sum
    valgtVerdi = `${ytdAar}-hittil`
  } else {
    const valgtIso = valgt && /^\d{4}-\d{2}$/.test(valgt) ? `${valgt}-01` : null
    aktivPeriode = valgtIso && liste.includes(valgtIso) ? valgtIso : liste[0]
    valgtVerdi = aktivPeriode.slice(0, 7)
  }
  // Periodevindu: hittil = sum av månedene jan→valgt; måned = den ene måneden.
  const fra = hittil ? `${ytdAar}-01-01` : aktivPeriode
  const til = aktivPeriode

  // Én funksjon summerer linjene over perioden (RLS-scopet). Vi filtrerer
  // cluster vs. per-stasjon i JS. Summerer månedene selv — så måned/år henger
  // sammen og per-stasjon-hittil ikke blir null (Azets fyller hittil kun cluster).
  type SumRad = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; sortering: number | null; regnskap: number | null; budsjett: number | null }
  const [{ data: alle }, { data: stasjoner }, varsler] = await Promise.all([
    supabase.rpc('regnskap_sum', { p_fra: fra, p_til: til }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    bruker.retailerId ? hentRegnskapVarsler(supabase, bruker.retailerId, aktivPeriode).catch(() => []) : Promise.resolve([]),
  ])

  // ADMIN-GRENEN AGGREGERER. `?stasjon=<uuid>` borer ned i én stasjon;
  // uten den summeres kjeden. At sida TAALER det staar i rutetabellen,
  // ikke her - og appskallet leser den samme tabellen, saa velgeren i
  // toppstripen tilbyr «Alle stasjoner» noyaktig her.
  //
  // Butikksjef-grenen over er en ANNEN side bak samme URL: en skjermet
  // visning av egen stasjon, som ikke summerer. Derfor staar /regnskap
  // som aggregat KUN for retailer_admin.
  const stasjonsliste = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/regnskap', bruker.rolle, stasjonsliste.length),
  )

  const medAvvik = <T extends { regnskap: number | null; budsjett: number | null }>(r: T) => ({
    ...r, avvik: (r.regnskap ?? 0) - (r.budsjett ?? 0),
    index_pct: r.budsjett ? (((r.regnskap ?? 0) - r.budsjett) / r.budsjett) * 100 : null,
  })
  const etterSort = (a: { sortering: number | null }, b: { sortering: number | null }) => (a.sortering ?? 9999) - (b.sortering ?? 9999)
  const rader = (alle ?? []) as SumRad[]
  const linjer: Linje[] = rader.filter((r) => r.stasjon_id == null).map(medAvvik).sort(etterSort)
  const stasjonLinjer: Linje[] | null = valgtStasjon ? rader.filter((r) => r.stasjon_id === valgtStasjon).map(medAvvik).sort(etterSort) : null
  const erStasjon = valgtStasjon != null && (stasjonLinjer?.length ?? 0) > 0
  const visLinjer = erStasjon ? (stasjonLinjer ?? []) : linjer

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Per stasjon: omsetning + brutto («40 CR» om den finnes, ellers sum basis) +
  // driftskostnader (sum) → driftsresultat = brutto − drift. Viser hva HVER
  // stasjon faktisk tjener, ikke bare omsetning.
  const perStasjon = rader.filter((r) => r.stasjon_id != null)
  const sumSeksjon = (sid: string, seks: string, brukCR: boolean) => {
    const ls = perStasjon.filter((r) => r.stasjon_id === sid && r.seksjon === seks)
    const kilde = brukCR && ls.some((r) => r.kode === '40') ? ls.filter((r) => r.kode === '40') : ls.filter((r) => r.kode !== '40')
    return kilde.reduce((a, r) => a + (r.regnskap ?? 0), 0)
  }
  const stasjonsrader = [...new Set(perStasjon.map((r) => r.stasjon_id as string))]
    .filter((id) => navnFor.has(id))
    .map((id) => {
      const brutto = sumSeksjon(id, 'bruttofortjeneste', true)
      const drift = sumSeksjon(id, 'driftskostnader', false)
      return { navn: navnFor.get(id)!, regnskap: sumSeksjon(id, 'omsetning', true), brutto, resultat: brutto - drift }
    })
    .sort((a, b) => b.resultat - a.resultat)

  // Driftskostnader per konto, summert over alle stasjoner (samlet-visning).
  const kontoMap = new Map<string, { post: string; sortering: number; regnskap: number; budsjett: number }>()
  if (!valgtStasjon) {
    for (const r of perStasjon.filter((r) => r.seksjon === 'driftskostnader')) {
      const key = `${r.kode ?? ''}|${r.post}`
      const k = kontoMap.get(key) ?? { post: r.post, sortering: r.sortering ?? 9999, regnskap: 0, budsjett: 0 }
      k.regnskap += r.regnskap ?? 0
      k.budsjett += r.budsjett ?? 0
      kontoMap.set(key, k)
    }
  }
  const kostnadPerKonto = [...kontoMap.values()]
    .map((k) => ({ ...k, avvik: k.regnskap - k.budsjett, index: k.budsjett ? ((k.regnskap - k.budsjett) / k.budsjett) * 100 : null }))
    .sort((a, b) => a.sortering - b.sortering || b.regnskap - a.regnskap)

  const valgtNavn = valgtStasjon ? navnFor.get(valgtStasjon) ?? null : null
  const seksjon = (navn: string) => visLinjer.filter((l) => l.seksjon === navn)

  // KPI: cluster bruker navngitte totaler; stasjon bruker «40 CR»-linja.
  // Per stasjon finnes ingen «Resultat»-linje (kun cluster) → utelat den.
  const omsetningTotalt = erStasjon
    ? seksjon('omsetning').find((l) => l.kode === '40')
    : seksjon('omsetning').find((l) => /^omsetning totalt/i.test(l.post))
  const brutto = erStasjon
    ? seksjon('bruttofortjeneste').find((l) => l.kode === '40')
    : seksjon('bruttofortjeneste').find((l) => /^bruttofortjeneste/i.test(l.post))
  // To resultatlinjer i Azets-rapporten: «RESULTAT EX 9900» (før eierlønn 9900 —
  // det bedriften faktisk tjener) og «RESULTAT» (bunnlinjen, etter eierlønn).
  // Vi viser begge så det ikke ser ut som tap når eierlønnen er trukket fra.
  const resultatInkl = seksjon('resultat').find((l) => /^resultat$/i.test(l.post.trim()))
  const resultatEks = seksjon('resultat').find((l) => /9900/.test(l.post))

  const kpi = [
    { merke: 'Omsetning', l: omsetningTotalt },
    { merke: 'Bruttofortjeneste', l: brutto },
    ...(erStasjon ? [] : [
      ...(resultatEks ? [{ merke: 'Resultat eks. 9900', l: resultatEks }] : []),
      { merke: 'Resultat inkl. 9900', l: resultatInkl },
    ]),
  ]

  // Varsler: stasjonsvisning viser kun valgt stasjons varsler; ellers alle.
  const visVarsler = erStasjon ? varsler.filter((v) => v.omfang === valgtNavn) : varsler

  // NIVÅ 1 — svaret. Bunnlinja er hovedtallet når den finnes. Per stasjon
  // gjør den ikke det (resultatlinjene er kun på cluster-nivå), og da er
  // bruttofortjenesten det nærmeste stasjonen har til et resultat.
  const hoved = erStasjon
    ? { merke: 'Bruttofortjeneste', l: brutto }
    : resultatEks
      ? { merke: 'Resultat eks. 9900', l: resultatEks }
      : { merke: 'Resultat inkl. 9900', l: resultatInkl }
  const motHoved = motBudsjett(hoved.l?.regnskap ?? null, hoved.l?.budsjett ?? null)

  // Hva drar mest: en kostnad over budsjett, eller en inntekt under det.
  // Begge er kroner, så den største av de to vinner uansett hvilken side
  // av regnskapet den står på.
  const drivere = [storsteAvvik(seksjon('driftskostnader'), true), storsteAvvik(seksjon('omsetning'))]
    .filter((d): d is Driver => d != null)
    .sort((a, b) => Math.abs(b.avvik) - Math.abs(a.avvik))
  const svar = svaret(hoved.merke, motHoved, drivere[0] ?? null)

  const periodeTekst = hittil ? `Hittil i år ${ytdAar}` : manedAar.format(new Date(aktivPeriode))
  const omfang = erStasjon ? (valgtNavn ?? 'valgt stasjon') : 'hele clusteret'

  return (
    <>
      <Sidehode
        tittel="Regnskap"
        undertittel={svar ? `${svar}. ${periodeTekst} · ${omfang}` : `${periodeTekst} · ${omfang}`}
        handlinger={<AiKontekst tekst="Hva skiller seg ut?" sporsmal="Hva skiller seg mest ut i regnskapet for siste periode, og hvorfor?" />}
      />

      {/* Stasjonsvelgeren staar i toppstripen, ett sted for hele systemet.
          Perioden staar igjen - den er sidas eget sporsmaal. Se trinn 09. */}
      <div className="regnskap-velgere">
        <PeriodeVelger
          valgt={valgtVerdi}
          grupper={byggPeriodeGrupper(liste, true)}
          basePath="/regnskap"
          bevar={valgtStasjon ? { stasjon: valgtStasjon } : {}}
        />
      </div>

      <div className="sq-nokkelrad">
        {kpi.map(({ merke, l }) => {
          // Budsjettet sto her fra før, men bare som et tall ved siden av.
          // Det er differansen brukeren er ute etter.
          const mot = motBudsjett(l?.regnskap ?? null, l?.budsjett ?? null)
          // Regnskapet har en ekte fasit: budsjettet. Derfor er `bra`
          // satt her - i motsetning til paa produksjonsplanen, der
          // «over forslaget» er butikksjefens vurdering og ikke noe
          // systemet kan felle dom over.
          return (
            <Nokkeltall
              key={merke}
              merkelapp={merke}
              verdi={kr.format(l?.regnskap ?? 0)}
              sammenlignet={mot.tekst ?? undefined}
              bra={mot.bra ?? undefined}
            />
          )
        })}
      </div>

      <RegnskapVarsler varsler={visVarsler} />

      <Forklaring sporsmaal="Hvordan er tallene regnet ut?">
        <p>
          {hittil
            ? `Hittil i år summerer månedene januar til og med ${manedAar.format(new Date(aktivPeriode))}.`
            : `Tallene gjelder ${manedAar.format(new Date(aktivPeriode))} alene.`}{' '}
          Månedene summeres her, ikke i regnskapsrapporten — Azets fyller hittil-kolonnen
          kun på cluster-nivå, så per stasjon ville den ellers stått tom.
        </p>
        <p>
          «{hoved.merke}» er hovedtallet siden på: det er linja svaret over måles på.
          {erStasjon
            ? ' Per stasjon finnes ingen resultatlinje i rapporten, så bruttofortjenesten brukes i stedet.'
            : ' «Resultat eks. 9900» er før eierlønn — det bedriften faktisk tjener. «Resultat inkl. 9900» er bunnlinjen etter at eierlønnen er trukket fra.'}
        </p>
        <p>
          Det som «drar mest» er det største avviket målt i kroner, ikke i prosent:
          40 % over på en konto til 5 000 kr er 2 000 kr, mens 3 % over på personal er
          hele forklaringen. Linjer uten budsjett holdes utenfor — de kan ikke avvike
          fra noe. Avvik under 2 % regnes som truffet budsjett.
        </p>
      </Forklaring>

      {/* Ekte sammenligningsmatrise: stasjon mot stasjon nedover,
          omsetning mot brutto mot driftsresultat bortover. */}
      {!erStasjon && stasjonsrader.length > 0 && (
        <Datatabell tittel="Per stasjon" antall={stasjonsrader.length}>
            <thead>
              <tr><th>Stasjon</th><th>Omsetning</th><th className="mob-skjul">Brutto</th><th>Driftsresultat</th></tr>
            </thead>
            <tbody>
              {stasjonsrader.map((s) => (
                <tr key={s.navn}>
                  <td>{s.navn}</td>
                  <td>{kr.format(s.regnskap)}</td>
                  <td className="mob-skjul">{kr.format(s.brutto)}</td>
                  {/* Belopet er tallet, og fortegnet staar i det. Nivaaet
                      sier hva fortegnet BETYR - et negativt driftsresultat
                      krever noe av eieren. */}
                  <td>
                    <Status nivaa={s.resultat >= 0 ? 'normal' : 'handling'}>
                      {kr.format(s.resultat)}
                    </Status>
                  </td>
                </tr>
              ))}
            </tbody>
        </Datatabell>
      )}
      {!erStasjon && stasjonsrader.length > 0 && (
        <p className="undertittel sq-finstilt">Driftsresultat = bruttofortjeneste − driftskostnader per stasjon (før felleskostnader på selskapsnivå).</p>
      )}

      {['omsetning', 'bruttofortjeneste', 'driftskostnader'].map((navn) => (
        <Datatabell key={navn} tittel={SEKSJON_TITTEL[navn]}>
            <thead>
              <tr>
                <th>Post</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th className="mob-skjul">Avvik</th><th>Index</th>
              </tr>
            </thead>
            <tbody>
              {seksjon(navn).map((l, i) => {
                const visPip = navn !== 'driftskostnader' && l.index_pct != null && !/totalt$/i.test(l.post)
                return (
                  <tr key={i}>
                    <td>{l.post}</td>
                    <td>{kr.format(l.regnskap ?? 0)}</td>
                    <td className="mob-skjul">{kr.format(l.budsjett ?? 0)}</td>
                    <td className="mob-skjul">{kr.format(l.avvik ?? 0)}</td>
                    <td>
                      {visPip ? (
                        <Status nivaa={nivaaFraKlasse(avviksKlasse(l.index_pct!))}>
                          {prosent.format((l.index_pct ?? 0) / 100)}
                        </Status>
                      ) : (
                        l.index_pct != null ? prosent.format((l.index_pct ?? 0) / 100) : '—'
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
        </Datatabell>
      ))}

      {!erStasjon && kostnadPerKonto.length > 0 && (
        <Datatabell
          tittel="Kostnader per konto · hele kjeden"
          antall={kostnadPerKonto.length}
        >
            <thead>
              <tr>
                <th>Konto</th><th>Regnskap</th><th className="mob-skjul">Budsjett</th><th className="mob-skjul">Avvik</th><th>Mot budsjett</th>
              </tr>
            </thead>
            <tbody>
              {kostnadPerKonto.map((k, i) => {
                // Kostnad: over budsjett = dårlig (rød), godt under = bra (grønn).
                const klasse = k.index == null ? '' : k.index > 5 ? 'rod' : k.index < -5 ? 'gronn' : 'gul'
                return (
                  <tr key={i}>
                    <td>{k.post}</td>
                    <td>{kr.format(k.regnskap)}</td>
                    <td className="mob-skjul">{kr.format(k.budsjett)}</td>
                    <td className="mob-skjul">{kr.format(k.avvik)}</td>
                    <td>
                      {k.index == null ? '—' : <Status nivaa={nivaaFraKlasse(klasse)}>{prosent.format(k.index / 100)}</Status>}
                    </td>
                  </tr>
                )
              })}
            </tbody>
        </Datatabell>
      )}
    </>
  )
}
