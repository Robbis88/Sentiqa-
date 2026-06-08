// Standard opplæringsplan for bensinstasjon (nyansatt). Kan tilpasses per kjede.
export type Laerepunkt = { omrade: string; tekst: string }

export const STANDARD_OPPLARING: Laerepunkt[] = [
  // Kasse & salg
  { omrade: 'Kasse & salg', tekst: 'Innlogging og bruk av kassesystem' },
  { omrade: 'Kasse & salg', tekst: 'Varesalg, retur og makulering' },
  { omrade: 'Kasse & salg', tekst: 'Aldersgrense: tobakk, alkohol, lodd og spill' },
  { omrade: 'Kasse & salg', tekst: 'Drivstoff: pumpekontroll og prising' },
  { omrade: 'Kasse & salg', tekst: 'Kontanthåndtering og oppgjør' },

  // Hurtigmat
  { omrade: 'Hurtigmat', tekst: 'Håndhygiene og personlig hygiene' },
  { omrade: 'Hurtigmat', tekst: 'Tilberedning av pølser og hamburgere' },
  { omrade: 'Hurtigmat', tekst: 'Temperaturkontroll (IK-mat)' },
  { omrade: 'Hurtigmat', tekst: 'Holdbarhet, datomerking og kassasjon' },
  { omrade: 'Hurtigmat', tekst: 'Rengjøring av grill, koker og utstyr' },

  // Drift & rutiner
  { omrade: 'Drift & rutiner', tekst: 'Åpne og lukke stasjonen' },
  { omrade: 'Drift & rutiner', tekst: 'Varemottak og kontroll' },
  { omrade: 'Drift & rutiner', tekst: 'Daglige rutiner og sjekkpunkter' },
  { omrade: 'Drift & rutiner', tekst: 'Avvikshåndtering (S01)' },

  // HMS & sikkerhet
  { omrade: 'HMS & sikkerhet', tekst: 'Brannvern og slukkeutstyr' },
  { omrade: 'HMS & sikkerhet', tekst: 'Ran og trusler – rutiner' },
  { omrade: 'HMS & sikkerhet', tekst: 'Førstehjelp' },
  { omrade: 'HMS & sikkerhet', tekst: 'Drivstoffsøl og miljøhåndtering' },
]
