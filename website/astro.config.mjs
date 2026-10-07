// @ts-check
import { unified } from "@astrojs/markdown-remark";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";

const site = process.env.SITE || "https://chaosmos.studio";
const base = process.env.BASE_PATH || "/plumb/";

/**
 * Markdown images written as ![alt](path "caption") become a figure with a visible caption. The caption
 * is what a reader skims and what an image search reads next to the picture, so every blog image has one.
 */
function rehypeFigure() {
  /** @param {any} node */
  const walk = node => {
    if (!node.children) return;
    node.children = node.children.map(child => {
      if (child.type === "element" && child.tagName === "p" && child.children?.length === 1) {
        const img = child.children[0];
        if (img.type === "element" && img.tagName === "img" && img.properties?.title) {
          const caption = String(img.properties.title);
          delete img.properties.title;
          img.properties.loading = "lazy";
          img.properties.decoding = "async";
          return {
            type: "element",
            tagName: "figure",
            properties: { className: ["post-figure"] },
            children: [img, { type: "element", tagName: "figcaption", properties: {}, children: [{ type: "text", value: caption }] }],
          };
        }
      }
      walk(child);
      return child;
    });
  };
  return tree => walk(tree);
}

export default defineConfig({
  site,
  base,
  trailingSlash: "always",
  integrations: [
    mdx(),
    sitemap({
      filter: page => !page.includes("/og/") && !page.endsWith("/404/"),
    }),
  ],
  markdown: {
    processor: unified({ rehypePlugins: [rehypeFigure] }),
  },
  image: {
    service: { entrypoint: "astro/assets/services/sharp" },
    // Every image, Markdown ones included, gets a srcset, so a phone never downloads a 2400 px picture.
    layout: "constrained",
    responsiveStyles: true,
  },
});
