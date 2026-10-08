// @ts-check
import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";

const site = process.env.SITE || "https://chaosmos.studio";
const base = process.env.BASE_PATH || "/plumb/";

export default defineConfig({
  site,
  base,
  trailingSlash: "always",
  integrations: [
    sitemap({
      filter: page => !page.includes("/og/") && !page.endsWith("/404/"),
    }),
  ],
  image: {
    service: { entrypoint: "astro/assets/services/sharp" },
    // Every image gets a srcset, so a phone never downloads a 2400 px picture.
    layout: "constrained",
    responsiveStyles: true,
  },
});
