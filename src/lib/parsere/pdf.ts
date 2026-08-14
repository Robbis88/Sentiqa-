// PDF → tekst. Server-only: unpdf drar inn pdf.js, som ikke hører hjemme
// i klientbundelen (samme grunn som erBpFil ligger utenfor gjenkjenn.ts).
//
// Ligger separat fra stempling.ts med vilje. Parseren jobber på tekst, så
// den lar seg teste uten en fil på disk — og en CSV-eksport fra easy@work
// vil treffe nøyaktig samme kode uten at noe her er involvert.
import 'server-only'

// %PDF- i de fire første bytene. Filnavn og MIME-type lyver; magic bytes gjør
// det ikke, og en xlsx som er døpt om til .pdf skal få en ærlig feilmelding.
export function erPdf(data: Buffer): boolean {
  return data.length > 4 && data.subarray(0, 4).toString('latin1') === '%PDF'
}

// Er dette tekst og ikke en binaerfil? xlsx starter med PK (zip), PDF med
// %PDF. Alt annet som ser ut som lesbar UTF-8 i de forste kilobytene
// behandles som tekst - da faar en CSV en aerlig feilmelding i stedet for
// «zip-fila er korrupt».
export function erTekstfil(data: Buffer): boolean {
  if (data.length === 0) return false
  if (data.subarray(0, 2).toString('latin1') === 'PK') return false
  if (erPdf(data)) return false
  const prove = data.subarray(0, 4096)
  // Nullbytes finnes ikke i tekst, og de finnes i praktisk talt alle
  // binaerformater.
  return !prove.includes(0)
}

export async function pdfTilTekst(data: Buffer): Promise<string> {
  const { extractText, getDocumentProxy } = await import('unpdf')
  const dok = await getDocumentProxy(new Uint8Array(data))
  const { text } = await extractText(dok, { mergePages: true })
  return Array.isArray(text) ? text.join(' ') : text
}
