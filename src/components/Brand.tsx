export function Mark({ className = "" }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 40 40"
      fill="none"
      aria-hidden="true"
    >
      <path d="M5 8h8l7 17 7-17h8L22 35h-4L5 8Z" fill="currentColor" />
    </svg>
  );
}
export default function Brand() {
  return (
    <div className="brand" aria-label="VektorTV">
      VEKTOR<span className="brand-tv">TV</span>
    </div>
  );
}
