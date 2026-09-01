import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { manedAar } from '@/lib/format'
import { GenererKnapp } from './generer-knapp'
import { Sidehode, Tomtilstand } from '@/components/ui/side'
import { Signal } from '@/components/ui/status'
import { Sideramme } from '@/components/ui/sideramme'

// «Generer fokuspunkter» (AI per stasjon) kan ta litt — gi handlingen tid.
export const maxDuration = 60

type Punkt = {
  stasjon_id: string
  periode: string
  type: string
  tekst: string
  tittel: string | null
  kategori: string | null
}

export default async function FokusSide() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <Sideramme><p>Du har ikke tilgang til fokuspunkter.</p></Sideramme>
  }

  const supabase = await lagSupabaseServerKlient()
  const { data: siste } = await supabase
    .from('fokuspunkter')
    .select('periode')
    .order('periode', { ascending: false })
    .limit(1)
    .maybeSingle<{ periode: string }>()

  const [{ data: punkter }, { data: stasjoner }] = await Promise.all([
    siste
      ? supabase
          .from('fokuspunkter')
          .select('stasjon_id, periode, type, tekst, tittel, kategori')
          .eq('periode', siste.periode)
          .overrideTypes<Punkt[]>()
      : Promise.resolve({ data: [] as Punkt[] }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const perStasjon = new Map<string, { forbedring: Punkt[]; positivt: Punkt[] }>()
  for (const p of punkter ?? []) {
    const b = perStasjon.get(p.stasjon_id) ?? { forbedring: [], positivt: [] }
    if (p.type === 'forbedring') b.forbedring.push(p)
    else b.positivt.push(p)
    perStasjon.set(p.stasjon_id, b)
  }

  return (
    <Sideramme>
      <Sidehode
        tittel="Fokus"
        undertittel={siste
          ? `${manedAar.format(new Date(siste.periode))} · regnet ut fra regnskapet`
          : 'Hva hver stasjon bør se på, regnet ut fra regnskapet.'}
        handlinger={bruker.rolle === 'retailer_admin' ? <GenererKnapp /> : undefined}
      />

      {[...perStasjon.entries()].length === 0 ? (
        <Tomtilstand
          tittel="Ingen fokuspunkter ennå"
          forklaring={bruker.rolle === 'retailer_admin'
            ? 'Behandle et regnskap og trykk «Generer fokuspunkter» — da får hver stasjon to til tre ting å se på.'
            : 'Eier lager dem etter at regnskapet er behandlet.'}
        />
      ) : (
        // KORTET BLIR STAAENDE. Her er det ikke en layoutbeholder: hver
        // seksjon er EN stasjons bilde, og det er den enheten en eier
        // sammenligner og handler paa. Aa slaa dem sammen til en flat
        // liste ville blandet Bones' punkter med Vardens.
        //
        // DET SOM ER ENDRET er punktene. De laa som to kolonner med
        // fargede overskrifter og kulepunkter under - farge paa en
        // overskrift, ikke paa saken. Naa er hvert punkt et signal:
        // `mulighet` for det som gaar bra, `oppmerksomhet` for det som
        // er verdt et blikk. Samme ord, samme rekkefolge, men fargen
        // sitter paa den enkelte saken der den betyr noe.
        [...perStasjon.entries()].map(([id, b]) => (
          <section className="kort" key={id}>
            <h2>{navnFor.get(id) ?? '—'}</h2>
            {/* OVERSKRIFTENE BLIR STAAENDE. Forste utgave lot nivaaet paa
                signalet baere skillet mellom «bra» og «verdt et blikk» -
                altsaa fargen alene. Den som ikke ser farge, mistet da
                inndelingen helt. Nivaaet forsterker overskriften; det
                erstatter den ikke. */}
            {b.positivt.length > 0 && (
              <>
                <h3>Bra jobbet</h3>
                {b.positivt.map((p, i) => (
                  <Signal key={`p${i}`} nivaa="mulighet" tittel={p.tittel ?? 'Bra jobbet'}>
                    {p.tekst}
                  </Signal>
                ))}
              </>
            )}
            {b.forbedring.length > 0 && (
              <>
                <h3>Verdt et blikk</h3>
                {b.forbedring.map((p, i) => (
                  <Signal key={`f${i}`} nivaa="oppmerksomhet" tittel={p.tittel ?? 'Verdt et blikk'}>
                    {p.tekst}
                  </Signal>
                ))}
              </>
            )}
          </section>
        ))
      )}
    </Sideramme>
  )
}
