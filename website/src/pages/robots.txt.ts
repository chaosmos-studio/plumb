import { absolute } from "../utils/url";

export function GET() {
  const body = [
    "User-agent: *",
    "Allow: /",
    "",
    `Sitemap: ${absolute("sitemap-index.xml")}`,
    `Sitemap: ${absolute("sitemap-images.xml")}`,
    "",
  ].join("\n");
  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
