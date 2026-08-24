import { loggUt } from '@/lib/auth/handlinger'

// Bruker er autentisert, men har ingen aktiv profil (rolle/tenant) ennå.
export default function IngenTilgangSide() {
  return (
    <main className="logg-inn">
      <div className="kort">
        <h1>Ingen tilgang</h1>
        <p>
          Kontoen din er ikke knyttet til en aktiv profil. Ta kontakt med
          eieren din, eller logg inn med en annen konto.
        </p>
        <form action={loggUt}>
          <button type="submit" className="primar">Logg ut</button>
        </form>
      </div>
    </main>
  )
}
