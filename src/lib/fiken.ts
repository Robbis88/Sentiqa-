import 'server-only'
import { env } from '@/lib/env'

// Fiken REST API v2. Auth: Bearer personlig API-token. EHF sendes via
// /invoices/send med method ['auto'] (prøver EHF → eFaktura → SMS → e-post).
const BASE = 'https://api.fiken.no/api/v2'

export type Fakturalinje = {
  productName: string
  unitPrice: number // NETTO i øre (eks. mva)
  quantity: number
  vatType: string // "HIGH" = 25 % mva, "NONE" hvis ikke mva-pliktig
  incomeAccount: string // salgskonto, f.eks. "3000"
}

function idFraLocation(loc: string | null): number | null {
  const siste = loc?.split('/').pop()
  const n = siste ? Number(siste) : NaN
  return Number.isFinite(n) ? n : null
}

async function post(token: string, sti: string, body: unknown): Promise<Response> {
  return fetch(`${BASE}${sti}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  })
}

export async function opprettKunde(
  token: string,
  slug: string,
  kunde: { navn: string; orgnr: string; epost?: string | null },
): Promise<number> {
  const r = await post(token, `/companies/${slug}/contacts`, {
    name: kunde.navn,
    organizationNumber: kunde.orgnr,
    email: kunde.epost || undefined,
    customer: true,
  })
  if (!r.ok) throw new Error(`Fiken kunde ${r.status}: ${await r.text()}`)
  const id = idFraLocation(r.headers.get('location'))
  if (!id) throw new Error('Fiken kunde: fant ingen contactId i svaret.')
  return id
}

export async function opprettFaktura(
  token: string,
  slug: string,
  f: { customerId: number; lines: Fakturalinje[]; bankAccountCode: string; issueDate: string; dueDate: string; ourReference?: string },
): Promise<number> {
  const r = await post(token, `/companies/${slug}/invoices`, {
    issueDate: f.issueDate,
    dueDate: f.dueDate,
    customerId: f.customerId,
    bankAccountCode: f.bankAccountCode,
    cash: false,
    lines: f.lines,
    ourReference: f.ourReference,
  })
  if (!r.ok) throw new Error(`Fiken faktura ${r.status}: ${await r.text()}`)
  const id = idFraLocation(r.headers.get('location'))
  if (!id) throw new Error('Fiken faktura: fant ingen invoiceId i svaret.')
  return id
}

export async function sendFaktura(
  token: string,
  slug: string,
  invoiceId: number,
  method: string[] = ['auto'],
): Promise<void> {
  const r = await post(token, `/companies/${slug}/invoices/send`, {
    invoiceId,
    method, // 'auto' prøver EHF først; bruk ['ehf'] for å kreve EHF
    includeDocumentAttachments: false,
  })
  if (!r.ok) throw new Error(`Fiken send ${r.status}: ${await r.text()}`)
}

export function fikenKonfigurert(): boolean {
  return Boolean(env.FIKEN_API_TOKEN && env.FIKEN_COMPANY_SLUG && env.FIKEN_BANK_ACCOUNT_CODE)
}
