import { ImageResponse } from "next/og";
import { BRAND_GLYPH_PATHS, BRAND_PRIMARY_HEX } from "@/lib/brand";

// OpsDeck favicon — brand-blue rounded square + white deck glyph,
// matching <BrandGlyph /> in the sidebar. Next.js renders this at
// build time and auto-injects <link rel="icon"> into <head>.
//
// Runs on the default Node.js runtime (the Edge runtime is deprecated
// in Next 16 and isn't needed for a static ImageResponse).

export const size = { width: 32, height: 32 };
export const contentType = "image/png";

export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: BRAND_PRIMARY_HEX,
          borderRadius: 6,
        }}
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#ffffff"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          {BRAND_GLYPH_PATHS.map((d) => (
            <path key={d} d={d} />
          ))}
        </svg>
      </div>
    ),
    { ...size },
  );
}
