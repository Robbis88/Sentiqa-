// =====================================================================
// Nettbrettets sidehode.
//
// EN NY PRIMITIV SKAL FORTJENE PLASSEN SIN, og denne fikk sju kall for
// aa be om den: /rutiner, /ikmat, /ikmat/maaling, /sjekkpunkt,
// /stempling, /anvisninger og /vaar-stasjon skrev alle den samme
// formen for haand — `<header className="tablet-hode"><h1>…</h1>`.
//
// Sju raa `<h1>` er ikke bare gjentakelse. Design-skrallen teller dem,
// og med god grunn: en raa overskrift er et sted der stilen kan gaa sin
// egen vei. Naa finnes den ETT sted, og en endring i hvordan
// nettbrettets hode ser ut treffer alle sju samtidig.
//
// FORMEN ER IKKE `Sidehode`. Lederens sidehode baerer modulnavn og
// handlingsknapper — «Anvisninger», «Ny anvisning». Nettbrettets baerer
// SVARET: «4 igjen», «Alle 12 målt». Modulnavnet sier hvor du er;
// tallet sier hva som gjenstaar, og det er det hun kom for.
//
// Derfor tar den ikke imot `handlinger`. Skal det gjoeres noe paa flata,
// staar handlingen i innholdet — ikke i hjornet av et hode.
// =====================================================================

export function TabletHode({
  tittel,
  undertittel,
}: {
  tittel: string
  undertittel?: React.ReactNode
}) {
  return (
    <header className="tablet-hode">
      <h1>{tittel}</h1>
      {undertittel != null && undertittel !== '' && (
        <p className="undertittel">{undertittel}</p>
      )}
    </header>
  )
}
