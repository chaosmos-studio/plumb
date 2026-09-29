import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { Resvg } from "@resvg/resvg-js";
import satori from "satori";
import { ogColours, site } from "../site.config";

// Social cards (1200x630) in the game's own colours and type, with its icon, for every page.
const W = 1200;
const H = 630;
const COLOURS = ogColours;

let assets: Promise<{ fonts: { name: string; data: Buffer; weight: 300 | 500; style: "normal" }[]; icon: string }> | null = null;

function load() {
  assets ??= (async () => {
    const dir = join(process.cwd(), "node_modules", "@fontsource", "outfit", "files");
    const [light, medium, icon] = await Promise.all([
      readFile(join(dir, "outfit-latin-300-normal.woff")),
      readFile(join(dir, "outfit-latin-500-normal.woff")),
      readFile(join(process.cwd(), "src", "assets", "icon.png")),
    ]);
    return {
      fonts: [
        { name: "Outfit", data: light, weight: 300 as const, style: "normal" as const },
        { name: "Outfit", data: medium, weight: 500 as const, style: "normal" as const },
      ],
      icon: `data:image/png;base64,${icon.toString("base64")}`,
    };
  })();
  return assets;
}

const el = (type: string, style: Record<string, unknown>, children?: unknown, extra: Record<string, unknown> = {}) => ({
  type,
  props: { style, children, ...extra },
});

export async function render(title: string, description: string, kicker: string) {
  const { fonts, icon } = await load();
  const tree = el(
    "div",
    { width: W, height: H, display: "flex", background: COLOURS.bg, fontFamily: "Outfit", position: "relative", overflow: "hidden" },
    [
      el("div", { position: "absolute", left: -120, top: -140, width: 420, height: 420, borderRadius: 999, background: COLOURS.orbs[0], opacity: 0.18 }),
      el("div", { position: "absolute", right: -80, bottom: -160, width: 460, height: 460, borderRadius: 999, background: COLOURS.orbs[1], opacity: 0.16 }),
      el("div", { position: "absolute", right: 220, top: -90, width: 220, height: 220, borderRadius: 999, background: COLOURS.orbs[2], opacity: 0.2 }),
      el("div", { display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "64px 72px", width: "100%" }, [
        el("div", { display: "flex", alignItems: "center", gap: 20 }, [
          el("img", { width: 72, height: 72, borderRadius: 18 }, undefined, { src: icon }),
          el("div", { fontSize: 46, fontWeight: 300, color: COLOURS.ink }, site.wordmark),
          el("div", { marginLeft: 16, fontSize: 22, fontWeight: 500, color: COLOURS.muted, letterSpacing: 3, textTransform: "uppercase" }, kicker),
        ]),
        el("div", { display: "flex", flexDirection: "column", gap: 18, maxWidth: 960 }, [
          el("div", { fontSize: title.length > 48 ? 58 : 70, fontWeight: 500, color: COLOURS.ink, lineHeight: 1.08, letterSpacing: -1.5 }, title),
          el("div", { fontSize: 28, fontWeight: 300, color: COLOURS.muted, lineHeight: 1.35 }, description.length > 130 ? `${description.slice(0, 127).trimEnd()}...` : description),
        ]),
        el("div", { display: "flex", alignItems: "center", gap: 14 }, [
          el("div", { width: 18, height: 18, borderRadius: 999, background: COLOURS.accent }),
          el("div", { fontSize: 24, fontWeight: 500, color: COLOURS.ink }, `Free on Google Play · ${site.url.replace(/^https:\/\//, "").replace(/\/$/, "")}`),
        ]),
      ]),
    ]
  );
  const svg = await satori(tree as never, { width: W, height: H, fonts });
  const png = new Resvg(svg, { fitTo: { mode: "width", value: W } }).render().asPng();
  return new Response(new Uint8Array(png), { headers: { "Content-Type": "image/png" } });
}
