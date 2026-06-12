// Vises mens en beskyttet side hentes/regnes (f.eks. dashbord med ukerapport,
// regnskapsanalyse). Layout/meny blir stående — kun innholdet får spinner.
export default function Laster() {
  return (
    <div className="laster-side">
      <span className="spinner" />
      <span>Laster …</span>
    </div>
  )
}
