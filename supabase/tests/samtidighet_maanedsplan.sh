#!/usr/bin/env bash
# =====================================================================
# DEN EKTE TO-SESJONS-TESTEN
# =====================================================================
# Racet vi lukket i `0217` kan ikke maales med én sesjon. Dette er
# selve feilen, saa Postgres-semantikken skal ikke bare beskrives.
#
# ---------------------------------------------------------------------
# INTERLEAVINGEN STYRES, DEN GJETTES IKKE
#
# B aapner en transaksjon og setter status - UTEN aa committe. A kaller
# skriveren og BLOKKERER paa radlaasen. Vi poller `pg_locks` til A
# faktisk staar og venter, og FOERST da committer B.
#
# En `sleep` her ville vaert en loegn: hadde A ikke rukket fram til
# laasen, ville testen degenerert til «B committet foerst» - den lette
# varianten - mens den saa ut til aa maale den vanskelige. Pollingen
# gjoer interleavingen VERIFISERT.
#
# Naar B committer, evaluerer A-sesjonens `on conflict do update ...
# where` mot den NYE radversjonen. Det er nettopp det en
# forhaandssjekk i TypeScript ikke kan gjoere.
#
# ---------------------------------------------------------------------
# SCENARIER
#
#   A  utkast -> avvist under kjoering   -> ikke skrevet, staar avvist
#   B  utkast -> sluppet under kjoering  -> ikke skrevet, staar sluppet
#   C  utkast som forblir utkast         -> SKREVET  (kanarifugl)
#   D  importens vei paa en avvist plan  -> ikke skrevet, batchen staar
#   E  batch med én laast og to gyldige  -> to skrevet, ingen exception
# =====================================================================
set -euo pipefail

: "${PGURL:?PGURL maa vaere satt}"

# =====================================================================
# EGEN SESJON, SLIK AT GRUPPEDRAPET FAKTISK ER VAART EGET
# =====================================================================
# `set -m` alene gir IKKE skriptet sin egen prosessgruppe: den setter
# bakgrunnsjobber i egne grupper, mens skriptet beholder gruppen det ble
# startet i. Da ville `$$` aldri vaert lik PGID, gruppedrapet aldri
# utloest - og vi ville trodd vi hadde et vern vi ikke hadde.
#
# `setsid --wait` gjoer skriptet til sesjons- OG gruppeleder, og venter
# paa det saa exitkoden naar fram. Da er `$$ = PGID`, og
# `kill -- -$PGID` treffer noeyaktig vaare egne prosesser.
#
# Finnes ikke `setsid`, kjoerer vi videre uten gruppedrapet. Da er den
# eksplisitte avslutningen av de to psql-barna den eneste opprydningen -
# og det staar skrevet framfor aa bli antatt.
if [ "${SAMTIDIGHET_EGEN_SESJON:-}" != "1" ] && command -v setsid > /dev/null 2>&1; then
  export SAMTIDIGHET_EGEN_SESJON=1
  exec setsid --wait bash "$0" "$@"
fi

RET=99999999-9999-4999-8999-9999999990a1
ST_A=99999999-9999-4999-8999-9999999990a2
ST_B=99999999-9999-4999-8999-9999999990a3
ST_C=99999999-9999-4999-8999-9999999990a4
# Seedens eier. `profiler.id` peker paa `auth.users`, saa fiksturen
# lager ingen ny profil - `sluppet_av` trenger bare EN gyldig.
PRO=33333333-3333-4333-8333-444444444444

q() { psql "$PGURL" -v ON_ERROR_STOP=1 -tAc "$1"; }

feil() { echo "FUNN: $*" >&2; exit 1; }

# =====================================================================
# STEGET SKAL ALDRI HENGE
# =====================================================================
#
# Foerste utgave kalte `feil` midt i en race, mens fd 9 sto aapen mot
# FIFO-en og to psql-prosesser laa i bakgrunnen. GitHub venter paa alle
# barn som holder utdatapipen - saa steget sto i 18 minutter etter at
# testen HADDE sagt «FUNN», og ble kansellert i stedet for aa feile.
#
# En test som henger i stedet for aa feile, er en test ingen leser.
#
# ---------------------------------------------------------------------
# EGEN PROSESSGRUPPE, OG EN KONTROLLERT DRAP
#
# `set -m` gir dette skallet sin egen prosessgruppe. Ved avslutning
# drepes gruppen - men BARE etter at vi har kontrollert at PGID
# faktisk er vaar egen og ikke arvet fra den som kalte oss. Et `kill`
# paa en negativ PID uten den sjekken ville kunnet ta ned hele
# CI-jobben.
# =====================================================================
set -m

ARBEIDSMAPPE=$(mktemp -d)
EGEN_PGID=$(ps -o pgid= -p $$ | tr -d ' ')

opprydding() {
  exec 9>&- 2>/dev/null || true

  # Barna foerst, hoeflig. De holder aapne transaksjoner, og slettingen
  # under ville ellers blokkere paa laasene deres.
  local barn
  barn=$(jobs -p 2>/dev/null || true)
  if [ -n "$barn" ]; then
    kill $barn 2>/dev/null || true
    wait 2>/dev/null || true
  fi

  # GRUPPEDRAPET, med selen paa. `kill -- -PGID` er farlig hvis PGID
  # ikke er vaar: da treffer den noen andres prosesser. Derfor to
  # vilkaar - den maa vaere et tall, og den maa vaere LIK denne
  # prosessens egen gruppe.
  if [ -n "$EGEN_PGID" ] && [ "$EGEN_PGID" = "$$" ] \
     && [ "$EGEN_PGID" -gt 1 ] 2>/dev/null; then
    kill -- "-$EGEN_PGID" 2>/dev/null || true
  fi

  rm -rf "$ARBEIDSMAPPE" 2>/dev/null || true

  q "delete from public.maanedsplan where retailer_id = '$RET';
     delete from public.stasjoner where retailer_id = '$RET';
     delete from public.retailers where id = '$RET';" >/dev/null 2>&1 || true
}
trap opprydding EXIT INT TERM

q "insert into public.retailers (id, navn) values ('$RET','Racetest')
     on conflict (id) do nothing;
   insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
     values ('$ST_A','$RET','9811','Race A','bydel'),
            ('$ST_B','$RET','9812','Race B','bydel'),
            ('$ST_C','$RET','9813','Race C','bydel')
     on conflict (id) do nothing;
" > /dev/null

[ "$(q "select count(*) from public.profiler where id = '$PRO'")" = "1" ]   || feil "fant ikke seedens eier ($PRO) - sluppet_av kan ikke settes"

rader() {           # $1 = stasjons-uuid-liste, komma-separert
  local ut="[" f=1
  for s in $(echo "$1" | tr ',' ' '); do
    [ $f -eq 0 ] && ut="$ut,"
    ut="$ut{\"stasjon_id\":\"$s\",\"maaned\":\"2026-07-01\",\"dom\":\"medvind\",\"ingress\":\"NY\",\"punkter\":[],\"merknad\":null,\"matkast\":null,\"usynlig\":null,\"rangering\":null}"
    f=0
  done
  echo "$ut]"
}

# =====================================================================
# Kjoerer ÉN race: B setter $2 paa $1 midt i A sin skriving.
# =====================================================================
# Hvert steg logges. Scenariet skal kunne LESES ut av loggen, ikke
# utledes av at det ikke feilet.
spor() { echo "      $*"; }

race() {
  local stasjoner="$1" ny_status="$2" maal="$3" jobb="${4:-null}"
  local mappe fifo out
  # EGEN MAPPE PER SCENARIO. Delte FIFO-navn mellom scenarier ville
  # gitt en gjenbrukt deskriptor dersom ett av dem feilet halvveis.
  mappe=$(mktemp -d "$ARBEIDSMAPPE/race.XXXXXX")
  fifo="$mappe/b"; mkfifo "$fifo"
  out="$mappe/a.ut"

  # Nullstill: alle stasjonene som utkast.
  q "delete from public.maanedsplan where retailer_id = '$RET';" > /dev/null
  for s in $(echo "$stasjoner" | tr ',' ' '); do
    q "insert into public.maanedsplan
         (retailer_id, stasjon_id, maaned, dom, ingress, punkter, status)
       values ('$RET','$s',date '2026-07-01','motvind','GAMMEL','[]'::jsonb,'utkast');" > /dev/null
  done

  # --- SESJON B: aapner, endrer, holder transaksjonen aapen ----------
  psql "$PGURL" -v ON_ERROR_STOP=1 -q -f "$fifo" > /dev/null &
  local bpid=$!
  exec 9>"$fifo"
  spor "B  transaksjon startet (pid $bpid)"
  printf 'begin;\nupdate public.maanedsplan set status = %s, sluppet_av = %s, sluppet_tid = %s where stasjon_id = %s;\n' \
    "'$ny_status'" \
    "$( [ "$ny_status" = "avvist" ] && echo null || echo "'$PRO'" )" \
    "$( [ "$ny_status" = "avvist" ] && echo null || echo now\(\) )" \
    "'$maal'" >&9
  spor "B  status -> $ny_status paa $maal, IKKE committet"
  # VENT TIL B FAKTISK HAR RADLAASEN.
  #
  # Her sto en loekke med `!= ""` som vilkaar. `count(*)` returnerer
  # ALLTID en verdi, saa den avsluttet paa foerste runde uten aa vente
  # paa noe som helst - en kontroll som ikke kan feile.
  #
  # `pg_locks` sier det direkte: B holder en `RowExclusiveLock` paa
  # tabellen naar updaten er utfoert.
  local i=0
  until [ "$(q "select count(*) from pg_locks
                 where granted and relation = 'public.maanedsplan'::regclass
                   and mode = 'RowExclusiveLock'")" -gt 0 ]; do
    i=$((i+1))
    [ $i -gt 200 ] && feil "sesjon B tok aldri laasen"
  done
  spor "B  holder RowExclusiveLock paa maanedsplan"

  # --- SESJON A: skriveren. Skal BLOKKERE paa radlaasen -------------
  psql "$PGURL" -v ON_ERROR_STOP=1 -tAc \
    "select stasjon_id || '=' || skrevet
       from public.skriv_maanedsplan_utkast('$(rader "$stasjoner")'::jsonb,
            '$RET'::uuid, $jobb);" > "$out" 2>&1 &
  local apid=$!
  spor "A  RPC startet (pid $apid)"

  # VERIFISER at A faktisk venter paa en laas. Uten dette maaler vi
  # kanskje bare «B committet foerst».
  # VENT TIL A FAKTISK VENTER PAA EN LAAS.
  #
  # Foerste utgave saa etter `pg_locks where not granted and relation =
  # maanedsplan`. Den kunne ALDRI treffe: en sesjon som venter paa en
  # rad en annen transaksjon holder, venter paa en TRANSACTIONID-laas,
  # og der er `pg_locks.relation` NULL. Filteret utelukket noeyaktig
  # den laasen A staar i.
  #
  # `pg_stat_activity` sier det direkte, og identifiserer A paa
  # spoerringsteksten - saa loekka ikke kan slippe videre paa en helt
  # annen ventende sesjon.
  i=0
  until [ "$(q "select count(*) from pg_stat_activity
                 where wait_event_type = 'Lock'
                   and query ilike '%skriv_maanedsplan_utkast%'")" -gt 0 ]; do
    i=$((i+1))
    if [ $i -gt 100 ]; then
      # EXIT 1, ikke bare en logglinje. Uten laaseobservasjonen har
      # testen ikke maalt racet, og da er «gikk bra» en loegn.
      feil "sesjon A blokkerte aldri - interleavingen ble ikke oppnaadd"
    fi
  done
  spor "A  observert ventende: wait_event_type = Lock"

  printf 'commit;\n' >&9
  exec 9>&-
  spor "B  COMMIT"
  wait "$bpid" || true
  wait "$apid" || feil "sesjon A feilet: $(cat "$out")"
  spor "A  fortsatte: $(tr '\n' ' ' < "$out")"

  cat "$out"
  rm -rf "$mappe"
}

# =====================================================================
# A  avvist under kjoering
# =====================================================================
svar=$(race "$ST_A" avvist "$ST_A")
echo "$svar" | grep -q "$ST_A=f" || feil "A: planen ble skrevet tross avvisning ($svar)"
[ "$(q "select status from public.maanedsplan where stasjon_id='$ST_A'")" = "avvist" ] \
  || feil "A: status er ikke avvist"
[ "$(q "select ingress from public.maanedsplan where stasjon_id='$ST_A'")" = "GAMMEL" ] \
  || feil "A: innholdet ble endret"
echo "A  avvist under kjoering       OK"

# =====================================================================
# B  sluppet under kjoering
# =====================================================================
svar=$(race "$ST_A" sluppet "$ST_A")
echo "$svar" | grep -q "$ST_A=f" || feil "B: planen ble skrevet tross slipp ($svar)"
[ "$(q "select ingress from public.maanedsplan where stasjon_id='$ST_A'")" = "GAMMEL" ] \
  || feil "B: innholdet ble endret"
echo "B  sluppet under kjoering      OK"

# =====================================================================
# C  KANARIFUGL: et utkast SKRIVES
# =====================================================================
q "delete from public.maanedsplan where retailer_id = '$RET';
   insert into public.maanedsplan
     (retailer_id, stasjon_id, maaned, dom, ingress, punkter, status)
   values ('$RET','$ST_A',date '2026-07-01','motvind','GAMMEL','[]'::jsonb,'utkast');" > /dev/null
svar=$(q "select stasjon_id || '=' || skrevet
            from public.skriv_maanedsplan_utkast('$(rader "$ST_A")'::jsonb, '$RET'::uuid, null);")
echo "$svar" | grep -q "$ST_A=t" || feil "C: et utkast ble IKKE skrevet - vakten maaler ingenting"
[ "$(q "select ingress from public.maanedsplan where stasjon_id='$ST_A'")" = "NY" ] \
  || feil "C: innholdet ble ikke oppdatert"
echo "C  utkast skrives (kanarifugl) OK"

# =====================================================================
# D  IMPORTENS VEI paa en avvist plan
#
# Samme funksjon, samme regel. Importen har ingen saerregel lenger:
# planen forblir avvist, innholdet staar, batchen rives ikke.
# =====================================================================
q "delete from public.maanedsplan where retailer_id = '$RET';
   insert into public.maanedsplan
     (retailer_id, stasjon_id, maaned, dom, ingress, punkter, status)
   values ('$RET','$ST_A',date '2026-07-01','motvind','GAMMEL','[]'::jsonb,'avvist');" > /dev/null
svar=$(q "select stasjon_id || '=' || skrevet
            from public.skriv_maanedsplan_utkast('$(rader "$ST_A")'::jsonb, '$RET'::uuid, null);")
echo "$svar" | grep -q "$ST_A=f" || feil "D: importen skrev om en avvist plan ($svar)"
[ "$(q "select status from public.maanedsplan where stasjon_id='$ST_A'")" = "avvist" ] \
  || feil "D: status er ikke lenger avvist"
echo "D  import mot avvist plan      OK"

# =====================================================================
# E  BATCHEN RIVES IKKE av én laast rad
# =====================================================================
q "delete from public.maanedsplan where retailer_id = '$RET';
   insert into public.maanedsplan
     (retailer_id, stasjon_id, maaned, dom, ingress, punkter, status)
   values ('$RET','$ST_A',date '2026-07-01','motvind','GAMMEL','[]'::jsonb,'avvist'),
          ('$RET','$ST_B',date '2026-07-01','motvind','GAMMEL','[]'::jsonb,'utkast');" > /dev/null
svar=$(q "select stasjon_id || '=' || skrevet
            from public.skriv_maanedsplan_utkast('$(rader "$ST_A,$ST_B,$ST_C")'::jsonb,
                 '$RET'::uuid, null);")
echo "$svar" | grep -q "$ST_A=f" || feil "E: den avviste ble skrevet"
echo "$svar" | grep -q "$ST_B=t" || feil "E: et gyldig utkast ble ikke skrevet"
echo "$svar" | grep -q "$ST_C=t" || feil "E: en ny rad ble ikke opprettet"
echo "E  batchen rives ikke          OK"

echo "samtidighet_maanedsplan: ingen funn"
