import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, datoLang } from '@/lib/format'
import { Opplaster } from './opplaster'
import { ForhandlingKnapp } from './forhandling-knapp'
import { Sidehode, Tomtilstand, Forklaring } from '@/components/ui/side'
import { Sidepanel } from '@/components/ui/sidepanel'

type Faktura = {
  id: string
  stasjon_id: string | null
  leverandor: string | null
  kategori: string | null
  faktura_dato: string | null
  belop_kr: number | null
  beskrivelse: string | null
}

export default async function AvtalevokterSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return <p>Kun eier har tilgang til Avtalevokter.</p>

  const supabase = await lagSupabaseServerKlient()
  const [{ data: fakturaer }, { data: stasjoner }] = await Promise.all([
    supabase
      .from('fakturaer')
      .select('id, stasjon_id, leverandor, kategori, faktura_dato, belop_kr, beskrivelse')
      .is('slettet_tid', null)
      .order('faktura_dato', { ascending: false })
      .overrideTypes<Faktura[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

  // Grupper per leverandør
  const perLev = new Map<string, Faktura[]>()
  for (const f of fakturaer ?? []) {
    const k = f.leverandor ?? 'Ukjent'
    const l = perLev.get(k) ?? []
    l.push(f)
    perLev.set(k, l)
  }

  // NIVÅ 1 på en liste: hvor mange, og hva de er verdt til sammen. Siden
  // åpnet med opplasteren — den sjeldneste handlingen her, og den eneste
  // som ikke sier noe om hva du allerede har.
  const antallFakturaer = (fakturaer ?? []).length
  const totaltKr = (fakturaer ?? []).reduce((a, f) => a + (f.belop_kr ?? 0), 0)
  const svar = antallFakturaer === 0
    ? 'Ingen fakturaer lest ennå'
    : `${perLev.size} ${perLev.size === 1 ? 'leverandør' : 'leverandører'} · ${antallFakturaer} ${antallFakturaer === 1 ? 'faktura' : 'fakturaer'} · ${kr.format(totaltKr)} totalt`

  const opplaster = (
    <Opplaster stasjoner={(stasjoner ?? []).map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))} />
  )

  return (
    <>
      <Sidehode
        tittel="Avtalevokter"
        undertittel={svar}
        handlinger={
          <Sidepanel
            knapp="Last opp faktura"
            tittel="Last opp faktura"
            beskrivelse="AI-en leser leverandør, beløp og dato ut av dokumentet. Du velger stasjon, eller lar den stå som felles."
          >
            {opplaster}
          </Sidepanel>
        }
      />

      {perLev.size === 0 ? (
        <Tomtilstand
          tittel="Ingen fakturaer lest ennå"
          forklaring="Last opp fakturaene fra en leverandør, så bygger Avtalevokteren en forbruksprofil på tvers av stasjonene — hva dere faktisk betaler, og hvor prisene spriker mellom butikkene."
          handling={opplaster}
        />
      ) : (
        [...perLev.entries()].map(([lev, liste]) => {
          const total = liste.reduce((a, f) => a + (f.belop_kr ?? 0), 0)
          return (
            <section className="kort" key={lev}>
              <h2>{lev} <span className="undertittel">· {liste[0].kategori ?? '—'} · totalt {kr.format(total)}</span></h2>
              <table className="tabell">
                <thead>
                  <tr><th>Stasjon</th><th>Dato</th><th>Beløp</th><th>Beskrivelse</th></tr>
                </thead>
                <tbody>
                  {liste.map((f) => (
                    <tr key={f.id}>
                      <td>{f.stasjon_id ? navnFor.get(f.stasjon_id) ?? '—' : 'Felles'}</td>
                      <td>{f.faktura_dato ? datoLang.format(new Date(f.faktura_dato)) : '—'}</td>
                      <td>{kr.format(f.belop_kr ?? 0)}</td>
                      <td>{f.beskrivelse}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <ForhandlingKnapp leverandor={lev} />
            </section>
          )
        })
      )}

      <Forklaring sporsmaal="Hva gjør Avtalevokteren med fakturaene?">
        <p>
          Hver faktura leses av AI-en, som trekker ut leverandør, kategori, dato og
          beløp. Fakturaene grupperes så per leverandør på tvers av stasjonene — det er
          hele poenget: én stasjon som betaler for mye ser normalt ut alene, og skiller
          seg først ut når de fem står ved siden av hverandre.
        </p>
        <p>
          «Forhandlingsgrunnlag» oppsummerer det dere kjøper fra én leverandør samlet,
          så du går inn i samtalen med totalen og ikke med én butikks tall.
        </p>
        <p>
          AI-en kan lese feil. Beløp og dato bør sjekkes mot fakturaen før tallene
          brukes i en forhandling.
        </p>
      </Forklaring>
    </>
  )
}
