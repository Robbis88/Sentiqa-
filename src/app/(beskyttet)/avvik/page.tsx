import { redirect } from 'next/navigation'
import { Sideramme } from '@/components/ui/sideramme'

// Avvik er flettet inn i IK-mat-siden (én meny). Gamle lenker sendes dit.
export default function AvvikSide() {
  redirect('/ikmat')
}
