#!/usr/bin/env bash
# =====================================================================
# SAMPLER DATABASEN MENS EN MAALING GAAR
# =====================================================================
#
# Finnes fordi en hengende serverhandling kan ha fem ulike aarsaker som
# ser helt like ut utenfra:
#
#   ventet paa databasetilkobling   mange tilkoblinger, ingen aktiv
#                                   sporring for vaar
#   ventet paa rad-/tabellaas       wait_event_type = 'Lock'
#   handlingen startet aldri        ingen sporring i det hele tatt
#   startet, returnerte aldri       sporringen staar aktiv og teller
#   svaret ble produsert, ikke
#   levert                          basen er rolig, nettverket henger
#
# Uten et bilde AV BASEN i det oeyeblikket forespoerselen hang, er
# enhver forklaring en gjetning. Den forrige var min.
#
# Rent lesende. Skriver til stdout; kalleren omdirigerer.
#
#   bruk:  PGURL=... bash supabase/tests/pg_sampler.sh > pg-samples.txt &
# =====================================================================
set -u

: "${PGURL:?PGURL maa vaere satt}"
INTERVALL="${INTERVALL:-2}"

while true; do
  echo "=== $(date -u +%H:%M:%S) ==="

  psql "$PGURL" -X -q -c "
    select count(*)                                        as tilkoblinger,
           count(*) filter (where state = 'active')        as aktive,
           count(*) filter (where state = 'idle')          as ledige,
           count(*) filter (where wait_event_type = 'Lock') as venter_paa_laas
      from pg_stat_activity
     where datname = current_database();" 2>&1

  psql "$PGURL" -X -q -c "
    select pid,
           state,
           wait_event_type,
           wait_event,
           round(extract(epoch from now() - query_start)::numeric, 1) as sek,
           left(regexp_replace(query, '[\n\r]+', ' ', 'g'), 110)      as sporring
      from pg_stat_activity
     where datname = current_database()
       and pid <> pg_backend_pid()
       and state is distinct from 'idle'
     order by query_start;" 2>&1

  # Blokkerende laaser, hvis det finnes noen. Tom i normaltilfellet.
  psql "$PGURL" -X -q -c "
    select blokkert.pid                as blokkert_pid,
           blokkerer.pid               as blokkerer_pid,
           left(blokkert.query, 80)    as blokkert_sporring,
           left(blokkerer.query, 80)   as blokkerer_sporring
      from pg_stat_activity blokkert
      join lateral unnest(pg_blocking_pids(blokkert.pid)) as b(pid) on true
      join pg_stat_activity blokkerer on blokkerer.pid = b.pid
     where cardinality(pg_blocking_pids(blokkert.pid)) > 0;" 2>&1

  sleep "$INTERVALL"
done
