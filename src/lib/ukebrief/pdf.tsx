import { Document, Page, Text, View, StyleSheet, renderToBuffer } from '@react-pdf/renderer'
import type { Rangert, Ukebrief } from './type'

// =====================================================================
// Ukebriefen som PDF.
//
// TREDJE VISNING AV SAMME BREV. Det er en reell kostnad, og den betales
// med aapne oeyne: en PDF kan legges ved en e-post, arkiveres og henges
// paa veggen — det kan verken siden eller e-posten.
//
// Prisen holdes nede paa én maate: DENNE FILA TAR INGEN BESLUTNINGER OM
// INNHOLD. Den leser `Ukebrief` og tegner den. Hvert ord, hver terskel
// og hver rekkefoelge kommer fra `bygg.ts`, akkurat som paa skjermen og
// i e-posten. Skal noe SIES annerledes, endres det der — ellers har vi
// tre brev i stedet for tre visninger av ett.
//
// Hex-farger med vilje, som i `epost.ts`: PDF kjenner ikke CSS-variabler.
// Fila staar derfor i UNNTAK i `farger.ts`, med paletten samlet i ett
// objekt som skal foelge `globals.css`.
// =====================================================================

const F = {
  tekst: '#0f1720',
  svak: '#64748b',
  kant: '#e2e8f0',
  primaer: '#2e7d6b',
  primaerSvak: '#e6f2ef',
  gronn: '#1f6152',
  gul: '#7a5321',
  rod: '#9b2c2c',
  hvit: '#ffffff',
} as const

/**
 * Tegn Helvetica ikke kan kode.
 *
 * PDF-standardfontene bruker WinAnsi, som IKKE har piler, tilnaermet-lik
 * eller ekte minus. `@react-pdf/renderer` kaster ikke paa dem — den
 * tegner et annet tegn. «↓ 22 %» ble til «" 22 %» i den foerste PDF-en,
 * og typecheck saa ingenting.
 *
 * Alternativet er aa bygge inn en egen font. Det ville lagt hundrevis av
 * kilobyte i bunten for fire tegn som uansett leses bedre som ord.
 */
const ERSTATT: [RegExp, string][] = [
  [/↑/g, '+'],   // opp
  [/↓/g, '-'],   // ned
  [/−/g, '-'],   // ekte minus
  [/≈/g, 'ca.'], // tilnaermet lik
]

export function pdfTekst(t: string): string {
  return ERSTATT.reduce((s, [fra, til]) => s.replace(fra, til), t)
}

const GRUNNLAG: Record<Rangert['grunnlag'], { navn: string; farge: string }> = {
  fakta: { navn: 'Fakta', farge: F.gronn },
  indikasjon: { navn: 'Sterk indikasjon', farge: F.primaer },
  hypotese: { navn: 'Mulig forklaring', farge: F.gul },
  mangler_data: { navn: 'Ikke nok data', farge: F.svak },
}

const s = StyleSheet.create({
  side: { paddingTop: 44, paddingBottom: 52, paddingHorizontal: 46, fontSize: 10, color: F.tekst, fontFamily: 'Helvetica' },
  uke: { fontSize: 9, color: F.svak, marginBottom: 4 },
  overskrift: { fontSize: 19, fontFamily: 'Helvetica-Bold', marginBottom: 7 },
  ingress: { fontSize: 11, lineHeight: 1.5, marginBottom: 18 },

  seksjon: { fontSize: 8, color: F.svak, letterSpacing: 0.7, marginTop: 16, marginBottom: 7 },

  handlingsboks: { backgroundColor: F.primaerSvak, borderRadius: 5, padding: 12, marginBottom: 4 },
  handlingstittel: { fontSize: 8, color: F.primaer, letterSpacing: 0.7, marginBottom: 7 },
  handling: { flexDirection: 'row', marginBottom: 5 },
  handlingsnr: { width: 14, fontFamily: 'Helvetica-Bold', color: F.primaer },
  handlingstekst: { flex: 1, lineHeight: 1.45 },

  funn: { borderTopWidth: 0.6, borderTopColor: F.kant, paddingTop: 8, marginBottom: 8 },
  funnTopp: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 3 },
  funnTittel: { fontFamily: 'Helvetica-Bold', flex: 1, paddingRight: 10 },
  funnTall: { color: F.svak },
  funnDetalj: { color: F.svak, lineHeight: 1.45, marginBottom: 5 },
  merkelapp: { fontSize: 7.5, borderWidth: 0.6, borderRadius: 2, paddingVertical: 1.5, paddingHorizontal: 4, alignSelf: 'flex-start' },

  skjemaHode: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 8, marginBottom: 5 },
  dager: { flexDirection: 'row', gap: 3 },
  dag: { flex: 1, borderWidth: 0.6, borderColor: F.kant, borderRadius: 3, paddingVertical: 5, alignItems: 'center' },
  dagNavn: { fontSize: 7.5, color: F.svak, marginBottom: 1 },
  dagTall: { fontSize: 8.5, fontFamily: 'Helvetica-Bold' },

  ikkevet: { fontSize: 9, color: F.svak, lineHeight: 1.4, marginBottom: 2 },

  bunn: {
    position: 'absolute', bottom: 26, left: 46, right: 46,
    flexDirection: 'row', justifyContent: 'space-between',
    fontSize: 8, color: F.svak, borderTopWidth: 0.6, borderTopColor: F.kant, paddingTop: 7,
  },
})

function Funn({ f }: { f: Rangert }) {
  const g = GRUNNLAG[f.grunnlag]
  return (
    // `wrap={false}` — et funn som brekker midt i detaljen blir to halve
    // paastander, og den andre halvparten leses uten tallet sitt.
    <View style={s.funn} wrap={false}>
      <View style={s.funnTopp}>
        <Text style={s.funnTittel}>{pdfTekst(f.tittel)}</Text>
        {f.endring ? <Text style={s.funnTall}>{pdfTekst(f.endring)}</Text> : null}
      </View>
      <Text style={s.funnDetalj}>{pdfTekst(f.detalj)}</Text>
      <Text style={[s.merkelapp, { color: g.farge, borderColor: g.farge }]}>{g.navn}</Text>
    </View>
  )
}

function dagsfarge(prosent: number | null): string {
  if (prosent === null) return F.svak
  if (prosent >= 100) return F.gronn
  if (prosent < 90) return F.rod
  return F.tekst
}

export function Brevdokument({ brief }: { brief: Ukebrief }) {
  return (
    <Document
      title={`Uke ${brief.ukenummer} — ${brief.stasjonNavn}`}
      author="Sentiqa"
      language="nb-NO"
    >
      <Page size="A4" style={s.side}>
        <Text style={s.uke}>Uke {brief.ukenummer} · {pdfTekst(brief.stasjonNavn)}</Text>
        <Text style={s.overskrift}>{pdfTekst(brief.overskrift)}</Text>
        <Text style={s.ingress}>{pdfTekst(brief.ingress)}</Text>

        {brief.handlinger.length > 0 && (
          <View style={s.handlingsboks} wrap={false}>
            <Text style={s.handlingstittel}>DETTE VILLE JEG TATT TAK I</Text>
            {brief.handlinger.map((h, i) => (
              <View key={h.fraSignal} style={s.handling}>
                <Text style={s.handlingsnr}>{i + 1}.</Text>
                <Text style={s.handlingstekst}>{pdfTekst(h.tekst)}</Text>
              </View>
            ))}
          </View>
        )}

        {brief.oppmerksomhet.length > 0 && (
          <>
            <Text style={s.seksjon}>TRENGER OPPMERKSOMHET</Text>
            {brief.oppmerksomhet.map((f) => <Funn key={f.id} f={f} />)}
          </>
        )}

        {brief.bra.length > 0 && (
          <>
            <Text style={s.seksjon}>DETTE GIKK BRA</Text>
            {brief.bra.map((f) => <Funn key={f.id} f={f} />)}
          </>
        )}

        {brief.skjema.map((b) => (
          <View key={b.navn} wrap={false}>
            <View style={s.skjemaHode}>
              <Text style={s.funnTittel}>{b.navn}</Text>
              <Text style={s.funnTall}>{b.prosent} % · {b.utfort} av {b.krevd}</Text>
            </View>
            <View style={s.dager}>
              {b.dager.map((d) => (
                <View key={d.dato} style={[s.dag, { borderColor: dagsfarge(d.prosent) }]}>
                  <Text style={s.dagNavn}>{d.ukedag}</Text>
                  <Text style={[s.dagTall, { color: dagsfarge(d.prosent) }]}>
                    {d.prosent === null ? '–' : `${d.prosent} %`}
                  </Text>
                </View>
              ))}
            </View>
          </View>
        ))}

        {brief.viIkkeVet.length > 0 && (
          <>
            <Text style={s.seksjon}>DETTE VET VI IKKE</Text>
            {brief.viIkkeVet.map((t) => <Text key={t} style={s.ikkevet}>• {pdfTekst(t)}</Text>)}
          </>
        )}

        <View style={s.bunn} fixed>
          <Text>Sentiqa · uke {brief.ukenummer} · {pdfTekst(brief.stasjonNavn)}</Text>
          <Text render={({ pageNumber, totalPages }) => `${pageNumber} av ${totalPages}`} />
        </View>
      </Page>
    </Document>
  )
}

/** Filnavnet er en del av dokumentet: en mappe med «ukebrief.pdf» tolv
    ganger er ikke et arkiv. */
export function filnavn(brief: Ukebrief): string {
  const stasjon = brief.stasjonNavn.replace(/[^\w\sÆØÅæøå-]/g, '').trim().replace(/\s+/g, '-')
  return `ukebrief-uke-${brief.ukenummer}-${stasjon}.pdf`
}

export async function lagPdf(brief: Ukebrief): Promise<Buffer> {
  return renderToBuffer(<Brevdokument brief={brief} />)
}
