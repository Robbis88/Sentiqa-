// Faste UI-tekster på tableten som skal oversettes (via Haiku-cache).
// Dynamisk innhold (rutiner, sjekkpunkt, meldinger, anvisninger) oversettes
// der det hentes. Hold til hele, selvstendige fraser (lett å oversette riktig).
//
// TALL SKAL IKKE STÅ I FRASEN. «4 ting igjen» kan ikke slås opp — det
// finnes uendelig mange av dem, og oppslaget bommer hver gang. Derfor
// står tallet utenfor og frasen inni: `{n} {t('ting igjen')}`. Dette var
// en ekte feil fram til bølge 5: nettbrettets viktigste overskrift sto på
// norsk uansett hvilket språk hun hadde valgt.
export const TABLET_ORD: string[] = [
  // Nav + skall. Tre faner fra bølge 5: I dag · Rutiner · Hjelp.
  'I dag', 'Rutiner', 'Hjelp', 'Logg ut', 'Varsler',
  // Hilsen
  'God natt', 'God morgen', 'God formiddag', 'God ettermiddag', 'God kveld',
  // Køen — «hva gjenstår på skiftet mitt»
  'Alt er gjort', 'Ingenting venter på deg akkurat nå.', 'ting igjen',
  'skulle vært gjort', 'og', 'ting til', 'rutine igjen', 'rutiner igjen',
  'produkter igjen å lage',
  // Beskjeder
  'Viktig', 'Beskjed',
  // Stempling — arbeidsdagen, ikke enheten
  'Stemple inn', 'Stemple ut', 'Stemple inn eller ut',
  'På jobb siden', 'Du er ikke stemplet inn',
  'Timene dine — ikke det samme som vakt-PIN-en',
  // Vår stasjon (sekundærflata)
  'Vår stasjon', 'Premie, vekst, skills og måling',
  'Hvordan vi ligger an. Ikke noe du må gjøre i dag.',
  'Merker', 'Det teamet har fått til',
  // Produksjonsplan (tablet)
  'Klart til morgen', 'Lagd', 'Produksjonsplan', 'produkter', 'lagd',
  'Produksjon', 'Dagens plan', 'Startpartiet er lagd', 'Alt er lagd',
  // Vekst
  'Vekst mot i fjor', 'Mat og drikke', 'Mat', 'Kald drikke', 'I dag', 'Måneden hittil',
  'på rad over fjoråret!', 'dag', 'dager', 'mot i fjor',
  // Premie + skills
  'Vår premiesaldo', 'Vunnet', 'Brukt', 'Igjen', 'Skills-score',
  'Helt perfekt! Hele teamet er på topp', 'Sterkt — nesten på topp!',
  'Bra jobba — fortsett sånn', 'På god vei', 'Her er det rom for å løfte seg',
  // Puls. Fjesene er skalaen; ordene er det skjermleseren sier.
  'Takk for svaret!', 'Kommentar (valgfri, anonym)', 'Ikke nå', 'Send', 'Sender …',
  'Veldig dårlig', 'Dårlig', 'Sånn passe', 'Bra', 'Veldig bra',
  // Sjekkpunkt — ett spørsmål av gangen
  'Sjekkpunkter', 'Ja', 'Nei', 'Se alle', 'av', 'Kritisk',
  'Alt er besvart', 'spørsmål', 'ferdig for i dag', 'Besvart i dag',
  'Ingen sjekkpunkter satt opp på denne stasjonen.',
  'Svaret ble ikke lagret. Prøv en gang til.',
  // IK-mat — én enhet av gangen
  'IK-mat', 'Alle kontrollpunkter, gruppert', 'Mer rutinearbeid',
  'Ingen kontrollpunkter satt opp på denne stasjonen.',
  'målt', 'trykk for å måle', 'utenfor kravet', 'Målt i dag', 'Alle',
  'Temperatur', 'Lagre', 'Lagrer …', 'Utenfor kravet', 'Strakstiltak',
  'Hva gjorde du med en gang?',
  'Skriv hva du gjorde med en gang. Da opprettes avviket automatisk, og butikksjefen får beskjed.',
  'Ingen enheter i denne gruppen.', 'Målingen ble ikke lagret. Prøv en gang til.',
  'Tilbake til vakta',
  // Send til sjef
  'Send melding til butikksjef', 'Generelt', 'Uhell', 'Nestenuhell',
  'Krenkelse fra kunde', 'Hva vil du si til sjefen?',
  'Beskrivelse av involvert kunde (valgfri)', 'Avbryt', 'Sendt til butikksjef',
  // Meldinger fra butikksjef
  'Meldinger fra butikksjef', 'Ingen nye meldinger fra butikksjef', 'Utført', 'Angre',
  'Ferdige', 'Frist', 'Frist i dag', 'Frist i morgen', 'Fristen er forbi',
  // Rutiner
  'Alt klart!', 'igjen', '1 igjen — nesten i mål!', 'Ingen aktive rutiner akkurat nå.',
  // Hjelp: anvisninger, lenker, nyheter, mine opplysninger
  'Slå opp når du trenger det.', 'Mer hjelp',
  'Lenker', 'Hurtiglenker for å hjelpe kunder', 'Ingen lenker lagt inn.',
  'Nyheter', 'Oppdateringer og tips',
  'Slik måler vi', 'Hva systemet lagrer om deg',
]
