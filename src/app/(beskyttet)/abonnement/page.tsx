import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr } from '@/lib/format'
import { beregnAbonnement } from '@/lib/pris'
import { settAbonnement } from './handlinger'
import { Sidehode, Forklaring } from '@/components/ui/side'

type Retailer = {
  navn: string
  org_nr: string | null
  faktura_epost: string | null
  aarlig_forskudd: boolean
  premium_avtalevokter: boolean
}

export default async function AbonnementSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Kun eier har tilgang til abonnement.</p>

  const supabase = await lagSupabaseServerKlient()
  const [{ data: retailer }, { count }] = await Promise.all([
    supabase
      .from('retailers')
      .select('navn, org_nr, faktura_epost, aarlig_forskudd, premium_avtalevokter')
      .maybeSingle<Retailer>(),
    supabase.from('stasjoner').select('*', { count: 'exact', head: true }).is('slettet_tid', null),
  ])

  const antallStasjoner = count ?? 0
  const premium = retailer?.premium_avtalevokter ?? false
  const aarlig = retailer?.aarlig_forskudd ?? false
  const { linjer, maaned, aarlig: aarsBelop } = beregnAbonnement(antallStasjoner, premium)

  // NIVÅ 1 på innstillinger: hva som gjelder NÅ. Sidehodet sa firmanavn og
  // antall stasjoner — to opplysninger man allerede har. Det man kommer hit
  // for er hva man betaler, og etter hvilken ordning.
  const svar = [
    `${kr.format(maaned)} per måned`,
    aarlig ? 'betales årlig i forskudd' : 'betales månedlig',
    premium ? 'Avtalevokter inkludert' : null,
    `${antallStasjoner} ${antallStasjoner === 1 ? 'stasjon' : 'stasjoner'}`,
  ].filter(Boolean).join(' · ')

  return (
    <>
      <Sidehode tittel="Abonnement" undertittel={`${retailer?.navn ?? 'Kjeden'} · ${svar}`} />

      <section className="nokkeltall">
        <div className="kpi">
          <span className="kpi-tall">{kr.format(maaned)}<small> /mnd</small></span>
          <span className="kpi-merke">Månedlig{aarlig ? ' (betales årlig)' : ''}</span>
        </div>
        <div className="kpi">
          <span className="kpi-tall">{kr.format(aarsBelop)}<small> /år</small></span>
          <span className="kpi-merke">Ved årlig forskudd (2 mnd gratis)</span>
        </div>
      </section>

      <section className="kort">
        <h2>Prisgrunnlag</h2>
        <table className="tabell">
          <thead><tr><th>Post</th><th>Antall</th><th>Sum/mnd</th></tr></thead>
          <tbody>
            {linjer.map((l) => (
              <tr key={l.navn}>
                <td>{l.navn}</td>
                <td>{l.antall ?? ''}</td>
                <td>{kr.format(l.sum)}</td>
              </tr>
            ))}
            <tr className="sum">
              <td><strong>Totalt</strong></td>
              <td></td>
              <td><strong>{kr.format(maaned)}/mnd</strong></td>
            </tr>
          </tbody>
        </table>
        <p className="undertittel" style={{ marginTop: '0.5rem' }}>
          Prisen følger antall stasjoner automatisk — legg til/fjern stasjoner under Stasjoner.
        </p>
      </section>

      <section className="kort">
        <h2>Fakturering (EHF)</h2>
        <p className="undertittel">
          Faktura sendes elektronisk på EHF til org.nr <strong>{retailer?.org_nr ?? '— mangler —'}</strong> via PEPPOL.
        </p>
        <form action={settAbonnement} className="skjema" style={{ maxWidth: 460 }}>
          <label className="felt">
            <span>Faktura-e-post (kopi/kontakt)</span>
            <input name="faktura_epost" type="email" defaultValue={retailer?.faktura_epost ?? ''} placeholder="regnskap@firma.no" />
          </label>
          <label className="felt avkryss">
            <input type="checkbox" name="aarlig_forskudd" defaultChecked={aarlig} />
            <span>Årlig forskudd (2 måneder gratis)</span>
          </label>
          <label className="felt avkryss">
            <input type="checkbox" name="premium_avtalevokter" defaultChecked={premium} />
            <span>Avtalevokter (premium · {kr.format(199)}/mnd)</span>
          </label>
          <button type="submit" className="sq-knapp primar">Lagre</button>
        </form>
      </section>

      <Forklaring sporsmaal="Hva skjer når jeg legger til eller fjerner en stasjon?">
        <p>
          Prisen følger antall stasjoner automatisk. Legger du til en stasjon under
          Stasjoner, endres grunnlaget her uten at du må gjøre noe — og motsatt når en
          fjernes. Du blir ikke bedt om å velge en pakke som må oppgraderes.
        </p>
        <p>
          Årlig forskudd gir to måneder gratis. Endrer du den innstillingen midt i en
          periode, slår den inn ved neste fakturering — ikke med tilbakevirkende kraft.
        </p>
        <p>
          Faktura går på EHF via PEPPOL til organisasjonsnummeret. E-postadressen over
          er en kopi og en kontakt, ikke der fakturaen sendes.
        </p>
      </Forklaring>
    </>
  )
}
