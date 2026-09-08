import { describe, expect, it } from 'vitest'
import { utenFastlonn } from './utenfastlonn'

const l = (ansattNr: string, timer: number) => ({ ansattNr, timer })

// Sandra på Lone, august 2026: 193,50 timer, timesats 285, fastlønn.
const LONE = new Map([['118', 'Sandra']])

describe('utenFastlonn', () => {
  it('holder den fastlønnedes linjer utenfor', () => {
    const u = utenFastlonn([l('118', 193.5), l('184', 190.44)], LONE)
    expect(u.beholdt.map((x) => x.ansattNr)).toEqual(['184'])
  })

  // ===================================================================
  // UTELATELSEN SKAL KUNNE SIES HØYT
  //
  // En person som forsvinner ut av lønnskosten uten et ord ser ut som en
  // person som ikke jobbet. Og numrene trengs til å rydde bort rader som
  // ble lagret FØR regelen fantes — en `upsert` fjerner ikke det den
  // ikke lenger produserer, så Sandras 57 957 ville blitt liggende for
  // alltid, usynlig for hver senere opplasting.
  // ===================================================================
  it('sier hvem som ble holdt utenfor, med nummer og navn', () => {
    const u = utenFastlonn([l('118', 8), l('118', 7), l('184', 8)], LONE)
    expect(u.utelatteNr).toEqual(['118'])
    expect(u.utelatteNavn).toEqual(['Sandra'])
  })

  it('navngir bare den som faktisk sto i fila', () => {
    // En fastlønnet som ikke var der i det hele tatt, er ikke noe som
    // ble holdt utenfor. Ellers ville meldinga navngitt folk hver måned
    // uten grunn, og da slutter man å lese den.
    const u = utenFastlonn([l('184', 8)], new Map([['118', 'Sandra'], ['9', 'Andre']]))
    expect(u.utelatteNavn).toEqual([])
    expect(u.utelatteNr).toEqual([])
    expect(u.beholdt).toHaveLength(1)
  })

  // ===================================================================
  // BARE `fastlonn` — DERFOR TAR FUNKSJONEN ET FERDIG UTVALG
  // ===================================================================
  // En tilkallingsvikar får betalt for timene sine; de føres bare utenom
  // Visma-fila. Fjernes de her, blir lønnskosten for lav — en annen
  // feil, ikke ingen feil. Og `null` er uavklart, ikke fastlønnet.
  //
  // Funksjonen ser bare kartet den får. Kanarifuglen er derfor at den
  // IKKE gjetter: gir kalleren et tomt kart, skal alt beholdes.
  // ===================================================================
  it('beholder alle når ingen er markert fastlønnet', () => {
    const u = utenFastlonn([l('118', 193.5), l('184', 190.44)], new Map())
    expect(u.beholdt).toHaveLength(2)
    expect(u.utelatteNavn).toEqual([])
  })

  it('tåler en tom fil', () => {
    const u = utenFastlonn([], LONE)
    expect(u.beholdt).toEqual([])
    expect(u.utelatteNr).toEqual([])
  })

  it('teller en person én gang, uansett hvor mange linjer hun har', () => {
    const u = utenFastlonn(
      Array.from({ length: 22 }, () => l('118', 8)),
      LONE,
    )
    expect(u.beholdt).toEqual([])
    expect(u.utelatteNr).toEqual(['118'])
  })
})
