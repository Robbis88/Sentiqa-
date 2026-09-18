import type { TabletKort } from '@/lib/malekort'
import { endring } from '@/lib/endring'

// RANGERINGEN STO SOM MEDALJER FOR TOPP TRE, og som «nr 4» for resten.
// Plasseringen fantes altsaa bare som et bilde for dem som hadde noe aa
// vaere stolte av - og et bilde en skjermleser ikke sier «forsteplass»
// om. Naa staar tallet for alle, og «nr 1 av 5» sier dessuten mer enn
// en medalje gjor alene.

export function formaterMalekort(verdi: number, enhet?: string, perKunde = false, avstand = false): string {
  const tall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 2 }).format(verdi)
  const enhetTekst = enhet === 'pst' ? (avstand ? 'prosentpoeng' : '%') : enhet === 'antall' ? 'stk.' : enhet === 'kunder' ? 'kunder' : enhet === 'kr_per_bong' ? 'kr per bong' : 'kr'
  return `${tall} ${enhetTekst}${perKunde ? ' per kunde' : ''}`
}

// Motiverende målekort-kort på tablet-hjem. Viser kun egen butikks stilling.
export function MalekortTablet({ kort }: { kort: TabletKort[] }) {

  return (
    <section className="tablet-seksjon maaling-tablet">
      <h2>Måling</h2>
      {kort.length === 0 && <p>Ingen målekort er delt med nettbrettet.</p>}
      <div className="maaling-tablet-kort">
        {kort.map((k) => {
          if (!k.klar) return <div className="maaling-tablet-rad" key={k.navn}><span className="mt-navn">{k.navn}</span><p className="mt-unna">{k.status === 'feil' ? 'Kunne ikke hente målingen. Prøv igjen senere.' : k.grunn ?? 'Venter på tall for perioden.'}</p></div>
          const plass = `nr ${k.rang}`
          const enhet = k.metrikk === 'kunder' && k.enhet === 'antall' ? 'kunder' : k.metrikk === 'snittbong' && k.enhet === 'kr' ? 'kr_per_bong' : k.enhet
          const unna = k.rang && k.rang > 1 && k.topp != null && k.verdi != null ? Math.abs(k.topp - k.verdi) : null
          return (
            <div className="maaling-tablet-rad" key={k.navn}>
              <span className="mt-navn">{k.navn}</span>
              <span className="mt-rang">{plass} <small>av {k.antall}</small></span>
              <span className="mt-unna">{k.etikett}</span>
              <span className="mt-verdi">{k.verdi != null ? formaterMalekort(k.verdi, enhet, k.perKunde) : 'Ingen tall'}</span>
              {k.vekstPst != null && (() => {
                const e = endring(k.vekstPst)
                return (
                  <span className={`mt-vekst ${e.farge}`}>
                    {e.pil ? `${e.pil} ` : ''}{e.fortegn}{e.tall} % mot i fjor
                  </span>
                )
              })()}
              {unna != null && unna > 0 && (
                <span className="mt-unna">{formaterMalekort(unna, enhet, k.perKunde, true)} til 1. plass</span>
              )}
            </div>
          )
        })}
      </div>
    </section>
  )
}
