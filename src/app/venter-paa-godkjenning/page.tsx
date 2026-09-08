import { loggUt } from '@/lib/auth/handlinger'

// =====================================================================
// KJEDEN FINNES, MEN ER IKKE SLUPPET INN ENNÅ
//
// `/registrer` er selvbetjent, og det skal den være — men en kjede som
// er live i det sekundet et skjema går, er en kjede ingen har sett på.
// `0190` la til `retailers.godkjent_tid`, og DAL-en sender hit så lenge
// den er null.
//
// SIDA SIER HVA SOM HAR SKJEDD OG HVA SOM SKJER NÅ. Alternativet var å
// nekte innlogging helt, men da ville en søker aldri fullført
// e-postbekreftelsen sin — og da vet vi ikke om adressen er ekte. Hun
// kommer altså inn, og møter denne.
//
// Ingen `hentInnloggetBruker()` her. Den er nettopp det som sender folk
// hit, og et kall herfra ville blitt en evig omdirigering.
// =====================================================================

export default function VenterPaaGodkjenningSide() {
  return (
    <main className="logg-inn">
      <div className="kort">
        <h1>Kontoen er opprettet</h1>
        <p>
          E-postadressen din er bekreftet, og kjeden er registrert. Den blir
          gjennomgått før den åpnes — det pleier å gå raskt, og du får beskjed
          på e-post når den er klar.
        </p>
        <p>
          Er det travelt, eller har du spørsmål i mellomtiden, svar på
          e-posten du fikk.
        </p>
        <form action={loggUt}>
          <button type="submit" className="primar">Logg ut</button>
        </form>
      </div>
    </main>
  )
}
