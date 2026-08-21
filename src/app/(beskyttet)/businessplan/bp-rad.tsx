import { kr } from '@/lib/format'
import { Status } from '@/components/ui/status'
import { alvor, domsord, gapAlvor } from '@/lib/regnskap/bp-dom'

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
}

/** «28 400 kr bak plan». Tallet formateres her, ordet kommer fra fasiten. */
function dom(kroner: number): string {
  return `${kr.format(Math.abs(Math.round(kroner)))} ${domsord(kroner)}`
}

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
        <p className="bp-planlagt">
          {rad.bp_omsetning_kr != null
            ? <>Planlagt {kr.format(rad.bp_omsetning_kr)}</>
            : 'Ingen plan lagt inn'}
        </p>
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

      {/* LEKKASJEN. To maater aa regne den samme margen paa: kassa tror
          den er X, regnskapet viser Y. Forskjellen er svinn, feilpris
          eller telling - og den vises ikke i salgstallene i det hele
          tatt. */}
      {(rad.teoretisk_brutto_pst != null || rad.faktisk_brutto_ytd_pst != null) && (
        <dl className="bp-brutto">
          <div>
            <dt>Kassen tilsier</dt>
            <dd>{rad.teoretisk_brutto_pst != null
              ? `${rad.teoretisk_brutto_pst.toFixed(1).replace('.', ',')} %` : '—'}</dd>
          </div>
          <div>
            <dt>Regnskap hittil i år</dt>
            <dd>{rad.faktisk_brutto_ytd_pst != null
              ? `${rad.faktisk_brutto_ytd_pst.toFixed(1).replace('.', ',')} %` : '—'}</dd>
          </div>
          <div className="bp-gap">
            <dt>Gap</dt>
            <dd>
              {gap != null ? (
                <Status nivaa={gapAlvor(gap)}>
                  {`${gap.toFixed(1).replace('.', ',')} pp`}
                </Status>
              ) : '—'}
            </dd>
          </div>
        </dl>
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
