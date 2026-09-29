import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

// One folder per post: src/content/blog/<slug>/index.md(x) with its images beside it in images/, so a
// post and its pictures move together and every image is optimised by Astro at build time.
const blog = defineCollection({
  loader: glob({
    base: "./src/content/blog",
    pattern: "*/index.{md,mdx}",
    generateId: ({ entry }) => entry.replace(/\/index\.mdx?$/, ""),
  }),
  schema: ({ image }) =>
    z.object({
      // Search engines cut titles near 60 characters and descriptions near 160.
      title: z.string().max(70),
      description: z.string().min(70).max(170),
      pubDate: z.coerce.date(),
      updatedDate: z.coerce.date().optional(),
      authors: z.array(z.string()).min(1),
      tags: z.array(z.string()).min(1),
      cover: image(),
      coverAlt: z.string().min(20),
      featured: z.boolean().default(false),
      video: z.string().optional(),
    }),
});

export const collections = { blog };
