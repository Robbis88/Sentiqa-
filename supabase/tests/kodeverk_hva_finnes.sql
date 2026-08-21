-- =====================================================================
-- Hva finnes? Stasjoner, perioder og datakilder
-- =====================================================================
--
-- KUN LESING. Kjor denne foerst, saa vet du hvilket butikknummer og
-- hvilken maaned du skal sette inn i kodeverk_mapping.sql.
--
-- «5101» i eksempelet var SEED-DATA - testkjeden som CI bruker. Den
-- finnes ikke i produksjon, og da traff `st`-blokka ingenting og alt
-- under falt sammen til null rader.
--
-- Fire lister: stasjonene dine, maanedene med BP, maanedene med
-- regnskap, og maanedene med salgsdata. Der de tre siste OVERLAPPER
-- for samme stasjon, kan mappingen si noe.
-- =====================================================================

select 'STASJON' as hva,
       s.butikknummer                as nokkel,
       s.navn                        as detalj,
       count(distinct d.dato)::text  as antall,
       max(d.dato)::text             as siste
from public.stasjoner s
left join public.daglig_salg d
       on d.stasjon_id = s.id and d.slettet_tid is null
      and d.dato >= current_date - 400
where s.slettet_tid is null
group by s.butikknummer, s.navn

union all

select 'BP-MAANED',
       s.butikknummer,
       to_char(r.periode, 'YYYY-MM-DD'),
       count(*)::text,
       round(sum(r.budsjett))::text
from public.regnskapslinjer r
join public.stasjoner s on s.id = r.stasjon_id
where r.seksjon = 'bp_bruttofortjeneste'
group by s.butikknummer, r.periode

union all

select 'REGNSKAP-MAANED',
       s.butikknummer,
       to_char(r.periode, 'YYYY-MM-DD'),
       count(*)::text,
       round(sum(r.regnskap))::text
from public.regnskapslinjer r
join public.stasjoner s on s.id = r.stasjon_id
where r.seksjon = 'bruttofortjeneste' and r.kode is not null
group by s.butikknummer, r.periode

union all

-- Hvor mange DISTINKTE koder finnes paa hvert salgsnivaa? Er tallene
-- like, er nivaaene sannsynligvis ikke ulike i praksis - og da er
-- «undergruppe» et navn uten et nivaa bak seg.
select 'SALGSNIVAA',
       s.butikknummer,
       'avdeling / vareomrade / varegruppe',
       count(distinct d.avdeling_kode) || ' / '
       || count(distinct d.vareomrade_kode) || ' / '
       || count(distinct d.varegruppe_kode),
       max(d.dato)::text
from public.daglig_salg d
join public.stasjoner s on s.id = d.stasjon_id
where d.slettet_tid is null and d.dato >= current_date - 120
group by s.butikknummer

order by 1, 2, 3;
