'use client'
import { useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { settStasjon } from './stasjon-handlinger'
import { stasjonsnavn, type Stasjon } from '@/lib/stasjonsvalg'

// =====================================================================
// Stasjonsvelgeren, ett sted.
//
// Ti sider spurte om dette hver for seg. Butikksjefen med én stasjon
// svarte ti ganger og fikk aldri et annet svar — og eieren måtte velge
// på nytt for hver side han gikk til.
//
// Vises ikke i det hele tatt når det bare finnes ett alternativ. En
// nedtrekksliste med ett valg ber om en beslutning som ikke finnes.
// =====================================================================

export function Stasjonskontekst({
  stasjoner,
  valgt,
  tillatAlle,
  synkroniser,
}: {
  stasjoner: Stasjon[]
  /** null = alle stasjoner samlet. */
  valgt: string | null
  tillatAlle: boolean
  /**
   * Verdien URL-en nettopp vant med, når den er en annen enn den huskede.
   *
   * URL-EN SKAL BLI DET NYE HUSKEDE VALGET. Uten det spretter brukeren
   * tilbake til forrige stasjon idet hun navigerer videre fra en delt
   * lenke - og da har systemet igjen to sannheter, bare forskjøvet ett
   * klikk.
   *
   * Serveren har allerede validert verdien mot brukerens egne stasjoner;
   * en lenke til noe hun ikke har tilgang til falt tilbake for den kom
   * hit, og skriver derfor aldri over hukommelsen. Skrivingen skjer her
   * og ikke i layouten fordi en serverkomponent ikke kan sette
   * informasjonskapsler under render.
   */
  synkroniser?: string | null
}) {
  const ref = useRef<HTMLFormElement>(null)
  const router = useRouter()

  /**
   * Et klikk NA slaar en URL fra i gaar.
   *
   * URL-en vinner over hukommelsen - det er riktig for en delt lenke, og
   * feil i det oyeblikket brukeren selv velger noe annet i toppstripen.
   * Sto det `?butikknummer=4177` i adressefeltet, ville valget hennes
   * blitt overstyrt av parameteren og klikket sett dodt ut.
   *
   * Derfor fjernes stasjonsparameteren fra URL-en naar hun velger selv.
   * Handlingen skriver hukommelsen, adressen slutter aa peke paa noe
   * annet, og de to er enige igjen.
   */
  function bytt() {
    ref.current?.requestSubmit()
    const url = new URL(window.location.href)
    if (url.searchParams.has('stasjon') || url.searchParams.has('butikknummer')) {
      url.searchParams.delete('stasjon')
      url.searchParams.delete('butikknummer')
      router.replace(url.pathname + url.search)
    }
  }

  useEffect(() => {
    if (!synkroniser) return
    const data = new FormData()
    data.set('stasjon', synkroniser)
    void settStasjon(data)
    // Etter handlingen er kapselen lik det URL-en ga, `synkroniser` blir
    // null ved neste render, og dette kjorer ikke igjen.
  }, [synkroniser])

  return (
    <form action={settStasjon} ref={ref} className="sq-stasjonskontekst">
      <label>
        {/* Etiketten er skjult visuelt, men ikke for skjermlesere: uten
            den er dette bare «kombinasjonsboks» i toppen av hver side. */}
        <span className="sq-skjult">Stasjon</span>
        <select
          name="stasjon"
          defaultValue={valgt ?? 'alle'}
          onChange={bytt}
        >
          {tillatAlle && <option value="alle">Alle stasjoner</option>}
          {stasjoner.map((s) => (
            <option key={s.id} value={s.id}>{stasjonsnavn(s)}</option>
          ))}
        </select>
      </label>
      {/* Uten JavaScript blir dette en vanlig knapp. Med, er den unødvendig. */}
      <noscript><button type="submit" className="liten">Bytt</button></noscript>
    </form>
  )
}
