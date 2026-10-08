import { getImage } from "astro:assets";
import type { ImageMetadata } from "astro";
import { absolute, absoluteFromRoot } from "../utils/url";

// An image sitemap: the home page and its screenshots, so they can be found in image search. The URLs are
// the optimised files the page itself serves. The blog's pictures are in the studio site's sitemap.
const shotImages = import.meta.glob<{ default: ImageMetadata }>("/src/assets/shots/*.{webp,png,jpg}", { eager: true });

async function url(img: ImageMetadata) {
  return absoluteFromRoot((await getImage({ src: img, width: Math.min(img.width, 1600) })).src);
}

export async function GET() {
  const pages: { loc: string; images: string[] }[] = [];
  pages.push({ loc: absolute(""), images: await Promise.all(Object.values(shotImages).map(m => url(m.default))) });
  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
    ...pages.map(p => `  <url><loc>${p.loc}</loc>${p.images.map(i => `<image:image><image:loc>${i}</image:loc></image:image>`).join("")}</url>`),
    "</urlset>",
  ].join("\n");
  return new Response(xml, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
}
