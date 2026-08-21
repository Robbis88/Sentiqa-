import { SPRAK } from '@/lib/sprak'
import { setSprak } from './sprak-handlinger'

// =====================================================================
// Spraakvelgeren: navnet paa spraaket, ikke flagget til et land.
//
// Sto med seks flaggemoji. Tre grunner til at de maatte gaa, og bare
// den siste er husregelen om emoji:
//
//   ET FLAGG ER IKKE ET SPRAAK. Polsk snakkes ikke bare i Polen, og
//   ukrainsk snakkes i dag av folk som ikke vil bli spurt om de er
//   russiske. Aa be noen velge nasjonalitet naar de skal velge ord er
//   en feil som er lett aa gjore og ubehagelig aa staa i.
//
//   NAVNET STAAR PAA SITT EGET SPRAAK. «Українська» kjennes igjen av
//   den som leser det, uten aa maatte kunne norsk foerst - og
//   «العربية» av den som leser arabisk. Et flagg krever at man kjenner
//   igjen et mønster; navnet krever bare at man leser sitt eget spraak.
//
//   OG EMOJI TEGNES ULIKT. Flaggene finnes ikke i det hele tatt i
//   standard skrift paa Windows; der ble 🇳🇴 til bokstavene «NO» i en
//   liten boks. Nettbrettets eget spraakvalg var altsaa allerede
//   halvveis tekst, avhengig av hvilken enhet det sto paa.
// =====================================================================
export function SprakVelger({ aktiv }: { aktiv: string }) {
  return (
    <div className="sprak-velger">
      {SPRAK.map((s) => (
        <form action={setSprak} key={s.kode}>
          <input type="hidden" name="kode" value={s.kode} />
          <button
            type="submit"
            className={`sprak-flagg ${aktiv === s.kode ? 'aktiv' : ''}`}
            title={s.navn}
            lang={s.kode}
            aria-pressed={aktiv === s.kode}
          >
            {s.navn}
          </button>
        </form>
      ))}
    </div>
  )
}
