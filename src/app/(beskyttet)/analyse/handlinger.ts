'use server'
import { genererRegnskapsanalyse, genererRegnskapsanalyseHittil } from '@/lib/ai/regnskapsanalyse'

// INGEN `revalidatePath` HER. Den sto paa EGEN rute, og da blir
// ruteroppdateringen en del av overgangen `useTransition` venter paa:
// serveren er ferdig, men knappen staar og spinner til hele sida har
// tegnet seg om. Paa en AI-analyse er det minutter.
//
// Samme kobling som ble maalt i Playwright-sporet 2026-08-29 og rettet i
// PR #114 - der med `useKvittering`. Her holder `router.refresh()` i
// knappen ETTER at svaret er kommet: kvittering foerst, liste etterpaa.

export async function generer(periode?: string) {
  return genererRegnskapsanalyse(periode)
}

export async function genererHeleAaret(aar?: string) {
  return genererRegnskapsanalyseHittil(aar)
}
