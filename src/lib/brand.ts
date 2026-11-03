/**
 * OpsDeck brand constants — the one place to change the product name
 * and brand colour used outside the theme system (page <title>, the
 * favicon, the sidebar wordmark).
 *
 * UI copy that mentions the product lives in `messages/*.json`
 * (`Sidebar.title`, `Metadata.description`, …). Internal identifiers
 * inherited from upstream wacrm (localStorage keys, the `wacrm_live_`
 * API-key prefix, `X-Wacrm-*` webhook headers) are deliberately kept
 * so existing keys, receivers and stored preferences keep working.
 */
export const BRAND_NAME = "OpsDeck";

/** Static brand hex, mirrors `--primary` of the `opsdeck` theme. */
export const BRAND_PRIMARY_HEX = "#2563eb";

/** Browser UI tint (mobile address bar) for the default light mode. */
export const BRAND_THEME_COLOR = "#ffffff";

/**
 * Placeholder OpsDeck mark: three stacked "deck" layers, drawn on a
 * 24×24 stroke grid (lucide conventions). Shared by <BrandGlyph /> and
 * the generated favicon (`src/app/icon.tsx`) so the two never drift.
 * Swap these paths when the final logo lands.
 */
export const BRAND_GLYPH_PATHS = [
  "M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z",
  "M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12",
  "M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17",
] as const;
