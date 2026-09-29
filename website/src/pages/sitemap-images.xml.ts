import { getImage } from "astro:assets";
import { getCollection } from "astro:content";
import type { ImageMetadata } from "astro";
import { absolute, absoluteFromRoot } from "../utils/url";

// An image sitemap: every page and the pictures on it, so the blog's graphics can be found in image
// search. The URLs are the optimised files the pages themselves serve.
const postImages = import.meta.glob<{ default: ImageMetadata }>("/src/content/blog/*/images/*.{webp,png,jpg}", { eager: true });
const shotImages = import.meta.glob<{ default: ImageMetadata }>("/src/assets/shots/*.{webp,png,jpg}", { eager: true });

async function url(img: ImageMetadata) {
  return absoluteFromRoot((await getImage({ src: img, width: Math.min(img.width, 1600) })).src);
}

export async function GET() {
  const pages: { loc: string; images: string[] }[] = [];
  pages.push({ loc: absolute(""), images: await Promise.all(Object.values(shotImages).map(m => url(m.default))) });
  for (const post of await getCollection("blog")) {
    const own = Object.entries(postImages).filter(([path]) => path.includes(`/blog/${post.id}/images/`));
    pages.push({ loc: absolute(`blog/${post.id}/`), images: await Promise.all(own.map(([, m]) => url(m.default))) });
  }
  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
    ...pages.map(p => `  <url><loc>${p.loc}</loc>${p.images.map(i => `<image:image><image:loc>${i}</image:loc></image:image>`).join("")}</url>`),
    "</urlset>",
  ].join("\n");
  return new Response(xml, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
}
