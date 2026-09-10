import { Merke } from '@/components/ui/merke'

// =====================================================================
// Kortet på sidene UTENFOR innlogging.
//
// Fire sider hadde samme sytten linjer hver — `<main className="logg-inn">`,
// merket, en `<h1>`, en undertittel og en bunnlinje. Da «Glemt passord?»
// skulle bli den femte, var valget mellom å skrive dem en gang til eller
// å samle dem. Det er samlet her.
//
// DET ER OGSÅ GRUNNEN TIL AT `<h1>` LIGGER HER OG IKKE I SIDENE.
// Design-skrallen teller rå `<h1>`, og tallet får ikke gå opp. Én i en
// komponent fem sider deler er ikke det samme som fem i fem sider — og
// det er nettopp forskjellen skrallen finnes for å måle.
//
// Bunnlinja er valgfri fordi den ikke er lik overalt: firmalinja hører
// hjemme der noen er i ferd med å gi fra seg noe (innlogging,
// passordbytte), ikke midt i en flyt de allerede er inne i.
//
// LENKENE I BUNNEN SENDES INN, DE BOR IKKE HER. Vakthunden leser lenker
// ut av sidefila og følger ikke importer. Flyttet /personvern hit, ble
// den «borte» fra /logg-inn i fasiten — og da kunne den slettes senere
// uten at noe ble rødt. Formen er delt, veiene ut er sidens egne.
// =====================================================================

export function AuthKort({
  tittel,
  undertittel,
  bunn = 'firma',
  bunnEkstra,
  children,
}: {
  tittel: string
  undertittel?: string
  /** `firma` = org.nr-linja, `ingen` = uten bunn. */
  bunn?: 'firma' | 'ingen'
  /** Sidens egne lenker, satt inn etter firmalinja. */
  bunnEkstra?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <main className="logg-inn">
      <div className="kort">
        <Merke />
        <h1>{tittel}</h1>
        {undertittel ? <p className="undertittel">{undertittel}</p> : null}
        {children}
      </div>
      {bunn === 'ingen' ? null : (
        <footer className="auth-bunn">
          R-G Invest AS · Org.nr 937 861 621{bunnEkstra}
        </footer>
      )}
    </main>
  )
}
