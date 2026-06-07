// Produksjonsplan-motor (PROSJEKT.md §7). Forenklet v1: vekter baseline fra
// salgshistorikk med værvarsel + stasjonstype + dagstype. Vær-følsomheten
// bruker fornuftige standardfaktorer til stasjonen har nok historikk til å
// lære sin egen (gradert verdi). Ren funksjon – testbar.

export type Vaerdag = { temp_maks: number | null; nedbor_mm: number | null }

// Multiplikator for én varegruppe gitt vær, stasjonstype og dagstype.
export function produksjonsfaktor(
  stasjonstype: string,
  vaer: Vaerdag | null,
  ukedag: number, // 0=søndag … 6=lørdag
  varegruppeNavn: string,
): number {
  let f = 1
  const erHelg = ukedag === 0 || ukedag === 6
  const varmt = vaer?.temp_maks != null && vaer.temp_maks >= 18 // «badevær» (§7 terskel)
  const kaldt = vaer?.temp_maks != null && vaer.temp_maks < 5
  const regn = vaer?.nedbor_mm != null && vaer.nedbor_mm >= 5
  const navn = varegruppeNavn.toLowerCase()

  // Stasjonstypens rytme (§7)
  if (stasjonstype === 'utfart') {
    if (erHelg && varmt) f *= 1.2 // utfart eksploderer solrike helger
    else if (!erHelg) f *= 0.9 // stille midt i uka
  } else if (stasjonstype === 'pendler') {
    if (erHelg) f *= 0.75 // pendler dør i helgene
  } else if (stasjonstype === 'sentrum') {
    if (erHelg) f *= 1.1 // kveldshandel/uteliv
  }

  // Varegruppe-vær (forenklet terskel-effekt)
  if (varmt && /(drikke|is|salat)/.test(navn)) f *= 1.15
  if (kaldt && /(kaffe|varm|suppe|oppvarmet)/.test(navn)) f *= 1.1
  if (regn && /(oppvarmet|kaffe|varm)/.test(navn)) f *= 1.1

  return f
}
