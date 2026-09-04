// Felles kilde for hva en BUTIKKSJEF får se av kostnader i regnskapet.
// Prinsipp: butikksjef ser kun kostnadene de selv kan påvirke. Alt annet
// (royalty, husleie, finans, varekost-detaljer, telefon, avskrivninger osv.)
// + selve «Resultat»-linjen skjules — det ligger på admin-nivå.
//
// Håndheves tre steder fra denne kilden: /regnskap (butikksjef-visning),
// AI-chatbotens kontekst, og auto-fokus etter regnskap.

// Personalkostnad samles til én linje «Personalkostnad».
export const BUTIKKSJEF_PERSONAL_KODER = new Set(['501', '502', '503', '505', '508', '509', '540', '541', '590'])

// Påvirkbare driftskostnader (St1-konto), i visningsrekkefølge.
export const BUTIKKSJEF_DRIFT_KODER = ['627', '628', '629', '632', '633', '634', '636', '638', '746'] as const

// Alle koder en butikksjef har innsyn i.
export const BUTIKKSJEF_KOSTNAD_KODER = new Set<string>([...BUTIKKSJEF_PERSONAL_KODER, ...BUTIKKSJEF_DRIFT_KODER])
