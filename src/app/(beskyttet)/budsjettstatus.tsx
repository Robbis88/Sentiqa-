import { kr } from '@/lib/format'
import { Datatabell } from '@/components/ui/side'
import { Status, type Statusnivaa } from '@/components/ui/status'

// Hvordan ligger stasjonene an mot BP akkurat nå?
//
// Tallene har ligget i systemet hele tiden — faktisk brutto per dag og
// BP-ens brutto per måned — uten at noen skjerm satte dem mot hverandre.
// /salg viser omsetning, /regnskap viser måneden som er avsluttet.
//
// Pro-rateringen er poenget: halvveis i august er ikke halve budsjettet
// brukt opp. Forventningen regnes fra stasjonens egen fordeling samme
// måned i fjor, og sier fra når den er et lineært anslag i stedet.

export type BudsjettRad = {
  stasjon_id: string
  butikknummer: string
  navn: string
  til_og_med: string
  brutto_hittil: number | null
  bp_maned: number | null
  andel_av_maned: number | null
  grunnlag: string
  forventet_naa: number | null
}

const pst = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 1 })

// Under 3 % er innenfor støyen fra én god eller dårlig dag. En side som
// roper på hver prosent blir ignorert etter tredje gang.
const TERSKEL = 3

// «Foran» er NORMAL, ikke en seier. Det var groent for; men en tabell
// der to av fire tilstander har farge bruker opp fargebudsjettet paa
// noe ingen skal gjore noe med. Ordene skiller dem fortsatt - grensene
// er de samme.
function tone(avvikPst: number): { nivaa: Statusnivaa; ord: string } {
  if (avvikPst <= -10) return { nivaa: 'kritisk', ord: 'Bak' }
  if (avvikPst <= -TERSKEL) return { nivaa: 'handling', ord: 'Litt bak' }
  if (avvikPst >= TERSKEL) return { nivaa: 'normal', ord: 'Foran' }
  return { nivaa: 'normal', ord: 'På plan' }
}

export function Budsjettstatus({ rader }: { rader: BudsjettRad[] }) {
  const med = rader.filter((r) => r.bp_maned && r.brutto_hittil !== null)
  if (med.length === 0) {
    return (
      <p className="undertittel">
        Ingen BP lastet opp for denne måneden ennå — da finnes det ikke noe å måle mot.
      </p>
    )
  }

  const beregnet = med
    .map((r) => {
      const forventet = r.forventet_naa ?? 0
      const brutto = r.brutto_hittil ?? 0
      return { ...r, forventet, brutto, avvik: brutto - forventet,
        avvikPst: forventet > 0 ? (brutto / forventet - 1) * 100 : 0 }
    })
    .sort((a, b) => a.avvikPst - b.avvikPst)

  const sumBrutto = beregnet.reduce((a, r) => a + r.brutto, 0)
  const sumForventet = beregnet.reduce((a, r) => a + r.forventet, 0)
  const samlet = sumForventet > 0 ? (sumBrutto / sumForventet - 1) * 100 : 0
  const anslag = beregnet.filter((r) => r.grunnlag !== 'i fjor')
  const tilOgMed = beregnet[0]?.til_og_med

  return (
    <>
      <p>
        Klyngen ligger <strong>{samlet >= 0 ? '+' : ''}{pst.format(samlet)} %</strong> mot
        budsjett så langt — {kr.format(sumBrutto)} mot {kr.format(sumForventet)} forventet.
      </p>
      {/* EKTE MATRISE: stasjon nedover, samme tre tall bortover. Det er
          nettopp sammenligningen mellom radene som er poenget, saa dette
          skal vaere en tabell - men gjennom Datatabell, som loeser
          vannrett rulling paa liten skjerm. */}
      <Datatabell>
        <thead>
          <tr>
            <th>Stasjon</th>
            <th className="tall">Brutto hittil</th>
            <th className="tall">Forventet nå</th>
            <th className="tall">Avvik</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {beregnet.map((r) => {
            const t = tone(r.avvikPst)
            return (
              <tr key={r.stasjon_id}>
                <td>{r.butikknummer} {r.navn}</td>
                <td className="tall">{kr.format(r.brutto)}</td>
                <td className="tall">{kr.format(r.forventet)}</td>
                <td className="tall">
                  {r.avvik >= 0 ? '+' : ''}{kr.format(r.avvik)}
                  <br />
                  <span className="undertittel">
                    {r.avvikPst >= 0 ? '+' : ''}{pst.format(r.avvikPst)} %
                  </span>
                </td>
                <td><Status nivaa={t.nivaa}>{t.ord}</Status></td>
              </tr>
            )
          })}
        </tbody>
      </Datatabell>
      <p className="undertittel">
        Målt til og med {tilOgMed} — salgstallene er alltid gårsdagens.
        {' '}Forventningen er BP-en fordelt etter hvor mye av måneden stasjonen
        normalt har levert innen denne datoen, ikke halve budsjettet halvveis i måneden.
        {anslag.length > 0 && (
          <> {anslag.map((r) => r.navn).join(', ')} mangler fjorårstall,
          så der er fordelingen et lineært anslag.</>
        )}
      </p>
    </>
  )
}
