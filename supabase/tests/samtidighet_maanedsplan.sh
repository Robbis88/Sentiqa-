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

RET=99999999-9999-4999-8999-9999999990a1
ST_A=99999999-9999-4999-8999-9999999990a2
ST_B=99999999-9999-4999-8999-9999999990a3
ST_C=99999999-9999-4999-8999-9999999990a4
PRO=99999999-9999-4999-8999-9999999990a5

q() { psql "$PGURL" -v ON_ERROR_STOP=1 -tAc "$1"; }

feil() { echo "FUNN: $*" >&2; exit 1; }

opprydding() {
  q "delete from public.maanedsplan where retailer_id = '$RET';
     delete from public.profiler where id = '$PRO';
     delete from public.stasjoner where retailer_id = '$RET';
     delete from public.retailers where id = '$RET';" >/dev/null 2>&1 || true
}
trap opprydding EXIT

q "insert into public.retailers (id, navn) values ('$RET','Racetest')
     on conflict (id) do nothing;
   insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
     values ('$ST_A','$RET','9811','Race A','bydel'),
            ('$ST_B','$RET','9812','Race B','bydel'),
            ('$ST_C','$RET','9813','Race C','bydel')
     on conflict (id) do nothing;
   insert into public.profiler (id, retailer_id, rolle, fullt_navn)
     values ('$PRO','$RET','retailer_admin','Race Eier')
     on conflict (id) do nothing;" > /dev/null

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
race() {
  local stasjoner="$1" ny_status="$2" maal="$3" jobb="${4:-null}"
  local fifo out
  fifo=$(mktemp -u); mkfifo "$fifo"
  out=$(mktemp)

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
  printf 'begin;\nupdate public.maanedsplan set status = %s, sluppet_av = %s, sluppet_tid = %s where stasjon_id = %s;\n' \
    "'$ny_status'" \
    "$( [ "$ny_status" = "avvist" ] && echo null || echo "'$PRO'" )" \
    "$( [ "$ny_status" = "avvist" ] && echo null || echo now\(\) )" \
    "'$maal'" >&9
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
    [ $i -gt 500 ] && feil "sesjon B tok aldri laasen"
  done

  # --- SESJON A: skriveren. Skal BLOKKERE paa radlaasen -------------
  psql "$PGURL" -v ON_ERROR_STOP=1 -tAc \
    "select stasjon_id || '=' || skrevet
       from public.skriv_maanedsplan_utkast('$(rader "$stasjoner")'::jsonb,
            '$RET'::uuid, $jobb);" > "$out" 2>&1 &
  local apid=$!

  # VERIFISER at A faktisk venter paa en laas. Uten dette maaler vi
  # kanskje bare «B committet foerst».
  # `relation`-filteret er ikke pynt: `not granted` uten det teller
  # hvilken som helst ventende laas i hele klyngen, og da kunne loekka
  # sluppet videre paa noe helt annet enn racet vi maaler.
  i=0
  until [ "$(q "select count(*) from pg_locks
                 where not granted
                   and relation = 'public.maanedsplan'::regclass")" -gt 0 ]; do
    i=$((i+1))
    if [ $i -gt 200 ]; then
      feil "sesjon A blokkerte aldri - interleavingen ble ikke oppnaadd"
    fi
  done

  printf 'commit;\n' >&9
  exec 9>&-
  wait "$bpid" || true
  wait "$apid" || feil "sesjon A feilet: $(cat "$out")"

  cat "$out"
  rm -f "$fifo" "$out"
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
