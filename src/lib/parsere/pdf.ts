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

export async function pdfTilTekst(data: Buffer): Promise<string> {
  const { extractText, getDocumentProxy } = await import('unpdf')
  const dok = await getDocumentProxy(new Uint8Array(data))
  const { text } = await extractText(dok, { mergePages: true })
  return Array.isArray(text) ? text.join(' ') : text
}
