import { ROM, ROM_LEDD } from './demo'

// =====================================================================
// LØNNSROMMET
//
// Dette er det sterkeste argumentet i hele systemet, og det sto ikke ett
// ord om det på sida. En kjede kjenner igjen problemet med én gang:
// lønnsbudsjettet er satt i kroner, brutto ble noe annet enn planlagt,
// og ingen vet hva rammen egentlig er før regnskapet kommer midt i neste
// måned.
//
// ---------------------------------------------------------------------
// PROSENTEN, IKKE KRONENE
//
// Produktet lærte dette den harde veien, og seksjonen arver lærdommen.
// Kronerommet sto øverst med «igjen å bruke» ved siden av, og en stasjon
// med −298 346 i grønt ble lest som «du har 298 000 igjen». Det er stikk
// i strid med hvordan tallet virker: at brutto ble høyere enn planlagt
// gir ikke mer lønn å bruke — det er ingen opptjent rettighet.
//
// Kontrollen er ANDELEN. Sier planen 51 %, er 51 % det de kan bruke.
// Ligger de på 55, er de over. Det tallet kan ikke leses som en
// invitasjon.
//
// ---------------------------------------------------------------------
// REGNESTYKKET STÅR ÅPENT
//
// Alternativet var å si «Sentiqa regner ut hvor mye du kan bruke på
// lønn», som er en påstand. Leddene står i den rekkefølgen de regnes,
// og hvert av dem sier hvor tallet kommer fra. En driftsleder som ser
// «× kalibrering 0,974» og «læres av seks avlagte måneder» vet
// nøyaktig hva han kjøper — og kan si nei til det.
//
// Serverkomponent: ingenting her er interaktivt.
// =====================================================================

const enPst = (n: number) => `${n.toLocaleString('nb-NO', {
  minimumFractionDigits: 1, maximumFractionDigits: 1,
})} %`

const kr = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })

export function Lonnsrom() {
  return (
    <section className="lp-seksjon" id="lonn">
      <div className="lp-ramme">
        <p className="lp-eyebrow">Lønn mot brutto</p>
        <h2 className="lp-h2">Rammen er en andel, ikke en sum.</h2>
        <p className="lp-ingress">
          Lønnsbudsjettet ditt står i kroner og forutsetter en bruttofortjeneste som
          kanskje ikke kom. Sentiqa måler den samme andelen mot det som faktisk kom —
          hver måned, uten å vente på regnskapet.
        </p>

        <div className="lp-rom">
          <div className="lp-rom-liste">
            <div className="lp-rom-hode">
              <h3>Lønn av brutto</h3>
              <span className="lp-demo">Demodata</span>
            </div>
            {ROM.map((r) => {
              const over = r.andel > r.krav
              return (
                <div className="lp-rom-rad" key={r.maaned}>
                  <span className="lp-rom-mnd">
                    {r.maaned}
                    {r.anslaatt && <span className="lp-rom-anslag">anslått</span>}
                  </span>
                  {/* FARGEN ALENE BÆRER IKKE BESKJEDEN. Kravet står som
                      tall ved siden av, og ordet «over»/«under» sier
                      hvilken vei — en prikk er en påminnelse for den som
                      ser den, ikke informasjon for den som ikke gjør det. */}
                  <span className={over ? 'lp-rom-v lp-v-rod' : 'lp-rom-v lp-v-gronn'}>
                    {enPst(r.andel)}
                  </span>
                  <span className="lp-rom-krav">
                    {`${over ? 'over' : 'under'} kravet på ${enPst(r.krav)}`}
                  </span>
                  <span className="lp-rom-brutto">{`brutto ${kr.format(r.bruttoKr)}`}</span>
                </div>
              )
            })}
          </div>

          <div>
            <h3>Måneden som ikke er avlagt.</h3>
            <p className="lp-rom-tekst">
              Regnskapet kommer midt i neste måned. Til da anslås bruttoen — og anslaget
              sier hvor hvert ledd kommer fra:
            </p>
            <ol className="lp-rom-ledd">
              {ROM_LEDD.map((l) => (
                <li key={l.ledd}>
                  <span className="lp-rom-ledd-navn">{l.ledd}</span>
                  <span className="lp-rom-ledd-v">{l.verdi}</span>
                  <span className="lp-rom-ledd-hvorfor">{l.forklaring}</span>
                </li>
              ))}
            </ol>
            <p className="lp-rom-tekst">
              Kalibreringen er det ene tallet som læres, og den blir bedre for hver
              regnskapsrapport. Treffer stasjonen marginen planen la opp til, står den
              på 1,00. Ligger den under, krymper rommet tilsvarende — og det er den
              beskjeden en butikksjef kan handle på i dag, ikke om tre uker.
            </p>
          </div>
        </div>

        <blockquote className="lp-sitat">
          «Et lavt svinn er allerede fanget når måneden lukkes, og å forskuttere det
          ville vært å låne av seg selv.»
          <cite>lonnskost/rom.ts · fra kildekoden</cite>
        </blockquote>
      </div>
    </section>
  )
}
