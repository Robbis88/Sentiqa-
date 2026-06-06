import { hentInnloggetBruker } from '@/lib/auth/dal'

export default async function OversiktSide() {
  const bruker = await hentInnloggetBruker()

  return (
    <>
      <h1>Oversikt</h1>
      <p className="undertittel">
        Velkommen, {bruker.fulltNavn ?? bruker.epost}.
      </p>

      <section className="kort">
        <h2>Fundamentet er på plass</h2>
        <p>
          Innlogging, tenant-isolasjon (RLS) og roller virker. Neste lag er
          datainntak (PROSJEKT.md §16 steg 2): e-post-inntak, kø og parsere.
        </p>
      </section>
    </>
  )
}
