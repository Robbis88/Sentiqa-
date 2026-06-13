// Delt (ikke 'use server'): IK-mat-rutinens tittel/tekst per frekvens-gruppe.
// Importeres både i server-action og i editor-siden.
export const IKMAT_RUTINE: Record<string, { tittel: string; tekst: string }> = {
  daglig: { tittel: '🌡️ IK-mat: kjøl & frys', tekst: 'Mål temperaturen på alle kjøl/frys-enheter og hak av.' },
  to_ukentlig: { tittel: '🌡️ IK-mat: oppvarming & varmholding', tekst: 'Mål kjernetemperatur på oppvarming/varmholding.' },
  ukentlig: { tittel: '🌡️ IK-mat: skyllevann', tekst: 'Mål skyllevann i oppvaskmaskinen.' },
}
