import { BRAND_GLYPH_PATHS } from "@/lib/brand";
import { cn } from "@/lib/utils";

/**
 * OpsDeck glyph, drop-in for a lucide icon (inherits `currentColor`,
 * sized via className). Decorative — pair it with visible text.
 */
export function BrandGlyph({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={cn("shrink-0", className)}
    >
      {BRAND_GLYPH_PATHS.map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  );
}
