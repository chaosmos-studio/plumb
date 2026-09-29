import type { ImageMetadata } from "astro";

// The site's own pictures by file name, so the config can name them instead of importing them.
const files = import.meta.glob<{ default: ImageMetadata }>("/src/assets/{shots,home}/*.{webp,png,jpg}", { eager: true });

export function picture(name: string): ImageMetadata {
  const hit = Object.entries(files).find(([path]) => path.split("/").pop()?.replace(/\.\w+$/, "") === name);
  if (!hit) throw new Error(`no picture named ${name} in src/assets/shots or src/assets/home`);
  return hit[1].default;
}
