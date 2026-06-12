'use client'
import { createContext, useContext } from 'react'

// Holder {norsk: oversatt} for tablet-tekstene. Server oversetter (Haiku-cache),
// klient-komponenter slår opp via useT().
const Ctx = createContext<Record<string, string>>({})

export function OversettProvider({ ord, children }: { ord: Record<string, string>; children: React.ReactNode }) {
  return <Ctx.Provider value={ord}>{children}</Ctx.Provider>
}

export function useT() {
  const ord = useContext(Ctx)
  return (s: string) => ord[s] ?? s
}
