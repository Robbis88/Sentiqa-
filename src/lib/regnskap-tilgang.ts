// Felles kilde for hva en BUTIKKSJEF får se av kostnader i regnskapet.
// Prinsipp: butikksjef ser kun kostnadene de selv kan påvirke. Alt annet
// (royalty, husleie, finans, varekost-detaljer, telefon, avskrivninger osv.)
// + selve «Resultat»-linjen skjules — det ligger på admin-nivå.
//
// Håndheves tre steder fra denne kilden: /regnskap (butikksjef-visning),
// AI-chatbotens kontekst, og auto-fokus etter regnskap.

// Personalkostnad samles til én linje «Personalkostnad».
// 506 REFUNDERT SYKELOENN STO IKKE HER, OG DET VAR EN FEIL.
//
// `LONNSKONTI` i `lonnskost/maaned.ts` har den - den er refusjonen av
// 505 Sykeloenn, foert negativt. /lonnskost regner den inn; /regnskap
// gjorde det ikke. Butikksjefen saa altsaa sykeloennen som kostnad,
// men ikke pengene tilbake, og «Personalkostnad» ble for hoey paa
// hver stasjon med sykefravaer.
//
// Den ble funnet da `0192` skulle gjore denne lista til en RLS-grense:
// hadde policyen speilet lista slik den sto, ville den kuttet 506 for
// butikksjefen, og loennskosten hadde blitt for hoey ogsaa der.
// `lonnskost-koder.test.ts` binder de to listene sammen naa.
export const BUTIKKSJEF_PERSONAL_KODER = new Set(['501', '502', '503', '505', '506', '508', '509', '540', '541', '590'])

// Påvirkbare driftskostnader (St1-konto), i visningsrekkefølge.
export const BUTIKKSJEF_DRIFT_KODER = ['627', '628', '629', '632', '633', '634', '636', '638', '746'] as const

// Alle koder en butikksjef har innsyn i.
export const BUTIKKSJEF_KOSTNAD_KODER = new Set<string>([...BUTIKKSJEF_PERSONAL_KODER, ...BUTIKKSJEF_DRIFT_KODER])

// =====================================================================
// DE SAMME GRENSENE, UTTRYKT I BEGREP OG IKKE I KODER
// =====================================================================
//
// Listene over er RAPPORTLINJEKODER, og en kode er en adresse - ikke en
// identitet. St1 renummererte i februar 2026: `628` betydde «Leie
// driftsmidler» foer og «Renovasjon» naa (se `parsere/kontoregister.ts`).
//
// For stasjonsarkene gaar det bra, fordi importen AVVISER filer fra den
// gamle epoken. Men bilagsbufferen (0199) baerer tolv maaneder bakover i
// hver fil, og de eldste radene ER fra det gamle skjemaet. Der ville en
// grense skrevet i koder sluppet leasingkostnaden gjennom som renovasjon.
//
// Derfor er grensen for bilagslinjer skrevet i `Kontobegrep`, som er
// stabilt over skiftet. `kontoregister.test.ts` binder de to listene
// sammen, slik `lonnskost-koder.test.ts` gjoer for loennskontiene.
export const BUTIKKSJEF_BEGREP = [
  // Personal, samlet til én linje i visningen.
  'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
  'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
  'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
  'andre_personalkostnader',
  // Paavirkbar drift, i visningsrekkefoelge.
  'renhold', 'renovasjon', 'broyting', 'utstyr_verktoy',
  'forbruksmateriell', 'rep_vedlikehold', 'pengehandtering',
  'kontorrekvisita', 'kassedifferanse',
] as const
