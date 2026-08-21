import { kr } from '@/lib/format'
import { Status } from '@/components/ui/status'
import { alvor, bruttoAlvor, domsord } from '@/lib/regnskap/bp-dom'

// =====================================================================
// Én avdeling, lest som en setning.
//
// IKKE EN KPI-VEGG. Seks tall ved siden av hverandre tvinger leseren til
// å regne selv — og det hun skal forstå på få sekunder er én ting:
//
//   «Vi selger mer enn i fjor, men ligger fortsatt bak planen —
//    og bruttoen lekker 5,2 prosentpoeng.»
//
// Derfor er raden bygget som tre trinn, i den rekkefølgen svaret bygges:
//
//   1. DOMMEN      kroner mot BP. Stort, først, med farge og ord.
//   2. FORKLARINGEN mot forventet i prosent, og mot i fjor. Mindre.
//   3. LEKKASJEN   de to bruttoene og gapet mellom dem.
//
// Fjoråret står ALDRI øverst. En stasjon kan ligge +8 % mot i fjor og
// samtidig være 70 000 bak planen, og det er planen timebudsjettet er
// bygget på. Setter vi veksten først, forteller vi butikksjefen at det
// går bra mens forventningen hun måles mot ikke er nådd.
// =====================================================================

export type BpRad = {
  gruppe_kode: string
  gruppe_navn: string | null
  periode_status: string
  bp_omsetning_kr: number | null
  burde_naa_omsetning: number | null
  faktisk_omsetning: number | null
  mot_bp_kr: number | null
  mot_bp_pst: number | null
  mot_ifjor_pst: number | null
  teoretisk_brutto_pst: number | null
  faktisk_brutto_ytd_pst: number | null
  brutto_gap_pst: number | null
  grunnlag: string | null
  kobling: Kobling | null
  ifjor_omsetning_kr: number | null
  bp_vekst_pst: number | null
  bp_brutto_ytd_pst: number | null
  brutto_mot_bp_pp: number | null
  brutto_mot_bp_kr: number | null
  brutto_mot_bp_indeks: number | null
}

/** De fire tilstandene `v_bp_status_avdeling` skiller mellom (0114). */
export type Kobling =
  | 'plan_med_salg'
  | 'plan_uten_salg'
  | 'plan_uten_kobling'
  | 'salg_uten_plan'

/**
 * Hva en rad uten dom faktisk er.
 *
 * FØR 0114 STO DET «Ingen plan lagt inn» PÅ ALLE FIRE. For to av dem var
 * det stikk motsatt av sannheten: `211 Selvvask`, `DRIFT` og `SYSTEM`
 * har budsjett — det er salget som mangler. Å lese det som «ingen plan»
 * flytter skylden fra kodeverket til butikksjefen, som ikke kan gjøre
 * noe med noen av delene.
 */
function utenDom(kobling: Kobling | null, bp: number | null): string {
  switch (kobling) {
    case 'plan_uten_kobling':
      return 'Har budsjett, men koden finnes ikke i salgsdataene — '
        + 'den kan ikke måles mot noe'
    case 'plan_uten_salg':
      return 'Har budsjett, men ingen omsetning denne måneden'
    case 'salg_uten_plan':
      return 'Selger, men har ikke budsjett denne måneden'
    default:
      return bp != null ? 'Ikke målt ennå' : 'Ingen plan lagt inn'
  }
}

/** «28 400 kr bak plan». Tallet formateres her, ordet kommer fra fasiten. */
function dom(kroner: number): string {
  return `${kr.format(Math.abs(Math.round(kroner)))} ${domsord(kroner)}`
}

/** Prosent med komma, eller en tankestrek naar tallet ikke finnes. */
const prosent = (v: number | null) =>
  (v == null ? '—' : `${v.toFixed(1).replace('.', ',')} %`)

const pst = (v: number) => `${v > 0 ? '+' : ''}${v.toFixed(1).replace('.', ',')} %`

export function BpAvdeling({ rad }: { rad: BpRad }) {
  const navn = rad.gruppe_navn ?? rad.gruppe_kode
  const kommende = rad.periode_status === 'kommende'

  // En måned som ikke har skjedd kan ikke ligge foran eller bak. Da står
  // budsjettet alene, uten dom.
  if (kommende || rad.mot_bp_kr == null) {
    return (
      <article className="bp-rad bp-rad-plan">
        <h3 className="bp-navn">{navn}</h3>
        {rad.bp_omsetning_kr != null && (
          <p className="bp-planlagt">Planlagt {kr.format(rad.bp_omsetning_kr)}</p>
        )}
        {/* En kommende maaned trenger ingen forklaring paa hvorfor den
            ikke er maalt - det staar i at den ikke har skjedd. */}
        {!kommende && (
          <p className="bp-planlagt">{utenDom(rad.kobling, rad.bp_omsetning_kr)}</p>
        )}
      </article>
    )
  }

  const gap = rad.brutto_gap_pst

  return (
    <article className="bp-rad">
      <div className="bp-topp">
        <h3 className="bp-navn">{navn}</h3>
        {/* DOMMEN. Ord OG farge - den som ikke skiller rodt fra graatt
            skal lese det samme som den som gjor det. */}
        <Status nivaa={alvor(rad.mot_bp_pst)}>{dom(rad.mot_bp_kr)}</Status>
      </div>

      <p className="bp-forklaring">
        {rad.mot_bp_pst != null && (
          <span className="bp-mot-plan">{pst(rad.mot_bp_pst)} mot forventet</span>
        )}
        {rad.mot_ifjor_pst != null && (
          // KONTEKST, IKKE DOM. Staar etter planen, i dempet skrift.
          <span className="bp-mot-ifjor">
            {pst(rad.mot_ifjor_pst)} mot samme periode i fjor
          </span>
        )}
      </p>

      {/* HVA PLANEN KREVER. Uten denne linja er «−55,8 % mot forventet»
          umulig aa handle paa: butikksjefen kan ikke se om avdelingen
          svikter, eller om planen ba om vekst som aldri kom. Det foerste
          er hennes bord - det andre er en samtale med St1 sentralt.

          BILVASK paa Lone er begge deler samtidig: salget ned 42 % mot i
          fjor, OG en plan som krevde +32 %. De legger seg oppaa
          hverandre til -56 %, og uten dette tallet ser det ut som drift
          alene. */}
      {rad.bp_vekst_pst != null && (
        <p className="bp-krav">
          Planen krever {pst(rad.bp_vekst_pst)} mot i fjor
          {rad.ifjor_omsetning_kr != null && (
            <span className="bp-krav-grunnlag">
              {' '}({kr.format(rad.ifjor_omsetning_kr)} i fjor)
            </span>
          )}
        </p>
      )}

      {/* BRUTTO: TRE TALL, OG BARE ETT AV DEM ER EN DOM.

          «Kassen er fasit paa en perfekt hverdag. BP-budsjett i brutto
           mot regnskap er fasiten paa pengene vi tjener. Sier BP 60 %,
           kassa 80 % og regnskapet 40 %, saa er gapet mellom BP og
           regnskap det som maa dekkes.»  - Robert, 2026-08-21

          Derfor er dette en STIGE og ikke tre likestilte tall: taket,
          loeftet, virkeligheten - og til slutt avstanden som maa
          dekkes inn. Bare den siste har farge.

          Foer dette sto «Gap» = kassa minus regnskap, med farge. For
          varm drikke ville den vaert roed hver eneste maaned uten et
          grep aa ta: kaffeavtaler gjor at kassa teller kopper som er
          solgt, mens tellingen ser alt som er BRUKT. Vi ville sendt
          butikksjefen etter et svinn som ikke finnes. */}
      {(rad.teoretisk_brutto_pst != null || rad.faktisk_brutto_ytd_pst != null
        || rad.bp_brutto_ytd_pst != null) && (
        <dl className="bp-brutto">
          <div>
            <dt>Kassen, perfekt dag</dt>
            <dd>{prosent(rad.teoretisk_brutto_pst)}</dd>
          </div>
          <div>
            <dt>Planen lover</dt>
            <dd>{prosent(rad.bp_brutto_ytd_pst)}</dd>
          </div>
          <div>
            <dt>Regnskapet viser</dt>
            <dd>{prosent(rad.faktisk_brutto_ytd_pst)}</dd>
          </div>
          {rad.brutto_mot_bp_pp != null && (
            <div className="bp-gap">
              <dt>{rad.brutto_mot_bp_pp < 0 ? 'Å dekke inn' : 'Over plan'}</dt>
              <dd>
                <Status nivaa={bruttoAlvor(rad.brutto_mot_bp_indeks)}>
                  {`${Math.abs(rad.brutto_mot_bp_pp).toFixed(1).replace('.', ',')} pp`}
                  {rad.brutto_mot_bp_kr != null
                    && ` · ${kr.format(Math.abs(rad.brutto_mot_bp_kr))}`}
                </Status>
              </dd>
            </div>
          )}
        </dl>
      )}

      {/* REGELEN GJELDER ALLE AVDELINGER, ikke bare varm drikke.
          Kassa er taket paa en perfekt dag overalt - mat kastes, drikke
          svinner, priser slaas feil, noe gis bort. Varm drikke er bare
          det tydeligste tilfellet, fordi kaffeavtaler gjor differansen
          stor OG helt normal.

          Denne linja staar naar differansen er stor nok til aa reise
          spoersmaalet «hvor ble det av margen», saa den som lurer faar
          svaret i stedet for aa gjette paa svinn. */}
      {gap != null && gap >= 10 && (
        <p className="bp-grunnlag">
          Kassen ligger {gap.toFixed(1).replace('.', ',')} prosentpoeng over
          regnskapet. Forskjellen er alt kassen ikke ser — svinn, kast,
          feilpris og det som gis bort. På varm drikke er den normalt stor
          fordi kaffeavtaler gir kopper uten et salg bak seg. Målestokken
          over er planen, ikke kassen.
        </p>
      )}

      {/* Sier om forventningen er regnet fra fjoraarets EGEN kurve eller
          fordelt jevnt. Uten den leses et anslag som en maaling. */}
      {rad.grunnlag === 'lineaert' && rad.periode_status === 'innevaerende' && (
        <p className="bp-grunnlag">
          Forventningen er fordelt jevnt over måneden — det finnes ikke
          fjorårstall for denne avdelingen å fordele etter.
        </p>
      )}
    </article>
  )
}
