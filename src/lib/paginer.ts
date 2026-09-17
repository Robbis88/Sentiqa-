// PostgREST kapper stille på 1000 rader. Alt som henter et ukjent antall
// rader må paginere, ellers regnes summer på en vilkårlig delmengde.
export async function hentAlt<T>(
  lag: (fra: number, til: number) => PromiseLike<{ data: T[] | null; error: unknown }>,
): Promise<T[]> {
  const ut: T[] = []
  for (let side = 0; side < 200; side++) {
    const { data, error } = await lag(side * 1000, side * 1000 + 999)
    if (error) throw new Error(`hentAlt: ${String(typeof error === 'object' && 'message' in error ? error.message : error)}`)
    if (!data) throw new Error('hentAlt: mangler data uten databasefeil')
    if (data.length === 0) return ut
    ut.push(...data)
    if (data.length < 1000) return ut
  }
  throw new Error('hentAlt: over 200 000 rader — avgrens spørringen')
}
