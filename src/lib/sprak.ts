// Språk for tableten. «mål» er språknavnet vi gir Claude Haiku ved oversettelse.
export const SPRAK = [
  { kode: 'no', flagg: '🇳🇴', navn: 'Norsk', maal: null },
  { kode: 'en', flagg: '🇬🇧', navn: 'English', maal: 'English' },
  { kode: 'pl', flagg: '🇵🇱', navn: 'Polski', maal: 'Polish' },
  { kode: 'lt', flagg: '🇱🇹', navn: 'Lietuvių', maal: 'Lithuanian' },
  { kode: 'uk', flagg: '🇺🇦', navn: 'Українська', maal: 'Ukrainian' },
  { kode: 'ar', flagg: '🇸🇦', navn: 'العربية', maal: 'Arabic' },
] as const

export function maalFor(kode: string): string | null {
  return SPRAK.find((s) => s.kode === kode)?.maal ?? null
}
export function erGyldigSprak(kode: string): boolean {
  return SPRAK.some((s) => s.kode === kode)
}
