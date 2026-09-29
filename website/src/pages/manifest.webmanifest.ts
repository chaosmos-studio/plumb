import { site } from "../site.config";
import { href } from "../utils/url";

export function GET() {
  return new Response(
    JSON.stringify({
      name: site.name,
      short_name: site.name,
      description: site.description,
      start_url: href(""),
      scope: href(""),
      display: "standalone",
      background_color: site.themeColor.light,
      theme_color: site.themeColor.light,
      icons: [
        { src: href("icon-192.png"), sizes: "192x192", type: "image/png" },
        { src: href("icon-512.png"), sizes: "512x512", type: "image/png" },
      ],
    }),
    { headers: { "Content-Type": "application/manifest+json" } }
  );
}
