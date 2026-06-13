// Delt, server-trygg modul (IKKE 'use client') — så både server-komponenter
// (admin-dashbord) og klient-komponenter (stasjonsrangering) kan importere
// AVDELINGER som en ekte array. Importeres en const fra en 'use client'-fil
// inn i en server-komponent, blir den en klient-referanse, ikke verdien.
export type Avd = { kode: string; navn: string; ikon: string }

// Drivstoff (10) og Pant (250) holdes utenfor butikksjef-/lederanalysene:
// drivstoff er kommisjon/volum utenfor butikkdriften, pant er gjennomgang.
// Sier lite om hvordan butikksjefen driver butikken → utelates generelt.
export const UTELAT_KODER = new Set(['10', '250'])

// Linjer som ikke skal telle i butikksjefens omsetning/BRF-summer: drivstoff +
// pant + «40 CR» (St1-totalen, som ellers dobbelteller mot avdelingene).
export const SKJUL_OMS_KODER = new Set([...UTELAT_KODER, '40'])

// St1-kontoplanen — salgsavdelinger med ikon (for kilde-velgeren).
export const AVDELINGER: Avd[] = [
  { kode: '120', navn: 'Mat', ikon: '🍔' },
  { kode: '130', navn: 'Varm drikke', ikon: '☕' },
  { kode: '140', navn: 'Kald drikke', ikon: '❄️' },
  { kode: '160', navn: 'Kioskvarer', ikon: '🍫' },
  { kode: '170', navn: 'Butikk', ikon: '🛒' },
  { kode: '180', navn: 'Tobakk', ikon: '🚬' },
  { kode: '190', navn: 'Fritidsartikler', ikon: '🎣' },
  { kode: '200', navn: 'Bil', ikon: '🛠️' },
  { kode: '210', navn: 'Bilvask', ikon: '🚗' },
]
