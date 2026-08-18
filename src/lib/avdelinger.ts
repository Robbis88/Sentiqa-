// Delt, server-trygg modul (IKKE 'use client') — så både server-komponenter
// (admin-dashbord) og klient-komponenter (stasjonsrangering) kan importere
// AVDELINGER som en ekte array. Importeres en const fra en 'use client'-fil
// inn i en server-komponent, blir den en klient-referanse, ikke verdien.
// Hadde et `ikon`-felt med emoji. Emoji som ikonografi er ute (bestemt
// 2026-08-13): de bar ingen betydning kolonnen «Kategori» ikke allerede
// bar, og «🛠️ Bil» mot «🚗 Bilvask» var lettere å forveksle enn navnene
// alene.
export type Avd = { kode: string; navn: string }

// Drivstoff (10) og Pant (250) holdes utenfor butikksjef-/lederanalysene:
// drivstoff er kommisjon/volum utenfor butikkdriften, pant er gjennomgang.
// Sier lite om hvordan butikksjefen driver butikken → utelates generelt.
export const UTELAT_KODER = new Set(['10', '250'])

// Linjer som ikke skal telle i butikksjefens omsetning/BRF-summer: drivstoff +
// pant + «40 CR» (St1-totalen, som ellers dobbelteller mot avdelingene).
export const SKJUL_OMS_KODER = new Set([...UTELAT_KODER, '40'])

// St1-kontoplanen — salgsavdelingene (for kilde-velgeren).
export const AVDELINGER: Avd[] = [
  { kode: '120', navn: 'Mat' },
  { kode: '130', navn: 'Varm drikke' },
  { kode: '140', navn: 'Kald drikke' },
  { kode: '160', navn: 'Kioskvarer' },
  { kode: '170', navn: 'Butikk' },
  { kode: '180', navn: 'Tobakk' },
  { kode: '190', navn: 'Fritidsartikler' },
  { kode: '200', navn: 'Bil' },
  { kode: '210', navn: 'Bilvask' },
]
