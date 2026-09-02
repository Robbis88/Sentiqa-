'use server'
import { genererAlleLederstotte } from '@/lib/ai/lederstotte'

// INGEN `revalidatePath` PAA EGEN RUTE. Den gjoer ruteroppdateringen til
// en del av overgangen `useTransition` venter paa: serveren er ferdig,
// men knappen staar og spinner til hele sida har tegnet seg om. Paa en
// AI-generering er det minutter.
//
// `router.refresh()` i knappen, ETTER at svaret er vist, gir samme
// oppdatering uten aa ta kvitteringen som gissel. Se PR #114 og
// `kvitteringsvakt.test.ts`.

export async function generer() {
  return genererAlleLederstotte()
}
