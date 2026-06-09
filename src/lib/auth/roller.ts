// Delt rolle-hjelper (tidligere duplisert i mange handlinger.ts).
export function erLeder(rolle: string): boolean {
  return rolle === 'retailer_admin' || rolle === 'butikksjef'
}
