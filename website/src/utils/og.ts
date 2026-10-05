import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { Resvg } from "@resvg/resvg-js";
import satori from "satori";
import { ogColours, site } from "../site.config";

// Social cards (1200x630) for every page, in the game's own colours and type: the icon and name, the page's
// title, and the game's own board tilted in on the right, bleeding off the edge, so a shared link shows the
// game rather than a line of text. The board is a capture, made by scripts/make_art.py (art.json, "og").
const W = 1200;
const H = 630;
const COLOURS = ogColours;
// The board stands a little taller than the card, so it is cut off top and bottom like a close-up.
const BOARD_H = 700;

type Assets = {
  fonts: { name: string; data: Buffer; weight: 300 | 500; style: "normal" }[];
  icon: string;
  board: { src: string; width: number; height: number };
};

let assets: Promise<Assets> | null = null;

function png(data: Buffer) {
  return { src: `data:image/png;base64,${data.toString("base64")}`, width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}

function load() {
  assets ??= (async () => {
    const dir = join(process.cwd(), "node_modules", "@fontsource", "outfit", "files");
    const [light, medium, icon, board] = await Promise.all([
      readFile(join(dir, "outfit-latin-300-normal.woff")),
      readFile(join(dir, "outfit-latin-500-normal.woff")),
      readFile(join(process.cwd(), "src", "assets", "icon.png")),
      readFile(join(process.cwd(), "src", "assets", "og_board.png")),
    ]);
    return {
      fonts: [
        { name: "Outfit", data: light, weight: 300 as const, style: "normal" as const },
        { name: "Outfit", data: medium, weight: 500 as const, style: "normal" as const },
      ],
      icon: png(icon).src,
      board: png(board),
    };
  })();
  return assets;
}

const el = (type: string, style: Record<string, unknown>, children?: unknown, extra: Record<string, unknown> = {}) => ({
  type,
  props: { style, children, ...extra },
});

export async function render(title: string, description: string, kicker: string) {
  const { fonts, icon, board } = await load();
  const boardW = Math.round((board.width * BOARD_H) / board.height);
  // Cut at a word, without a stray full stop or comma before the ellipsis.
  const blurb = description.length > 110
    ? `${description.slice(0, 107).replace(/\s+\S*$/, "").replace(/[.,;:]+$/, "")}...`
    : description;
  const tree = el(
    "div",
    { width: W, height: H, display: "flex", background: COLOURS.bg, fontFamily: "Outfit", position: "relative", overflow: "hidden" },
    [
      el("div", { position: "absolute", left: -160, top: -180, width: 520, height: 520, borderRadius: 999, background: COLOURS.orbs[0], opacity: 0.16 }),
      el("div", { position: "absolute", left: 300, bottom: -260, width: 520, height: 520, borderRadius: 999, background: COLOURS.orbs[1], opacity: 0.14 }),
      el("div", { position: "absolute", right: 120, top: -120, width: 380, height: 380, borderRadius: 999, background: COLOURS.orbs[2], opacity: 0.2 }),
      el("img", { position: "absolute", right: -90, top: (H - BOARD_H) / 2 + 10, width: boardW, height: BOARD_H }, undefined, {
        src: board.src,
        width: boardW,
        height: BOARD_H,
      }),
      // A soft fade from the ground over the board's near edge, so a long title stays readable.
      el("div", {
        position: "absolute",
        left: 0,
        top: 0,
        width: 760,
        height: H,
        backgroundImage: `linear-gradient(90deg, ${COLOURS.bg} 0%, ${COLOURS.bg} 72%, ${COLOURS.bg}00 100%)`,
      }),
      el("div", { position: "absolute", left: 0, top: 0, display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "58px 64px", width: 700, height: H }, [
        el("div", { display: "flex", alignItems: "center", gap: 22 }, [
          el("img", { width: 92, height: 92, borderRadius: 24 }, undefined, { src: icon }),
          el("div", { display: "flex", flexDirection: "column", gap: 4 }, [
            el("div", { fontSize: 56, fontWeight: 300, color: COLOURS.ink, lineHeight: 1 }, site.wordmark),
            el("div", { fontSize: 20, fontWeight: 500, color: COLOURS.muted, letterSpacing: 3, textTransform: "uppercase" }, kicker),
          ]),
        ]),
        el("div", { display: "flex", flexDirection: "column", gap: 16, maxWidth: 600 }, [
          el("div", { fontSize: title.length > 36 ? 54 : 66, fontWeight: 500, color: COLOURS.ink, lineHeight: 1.06, letterSpacing: -1.5 }, title),
          el("div", { fontSize: 26, fontWeight: 300, color: COLOURS.muted, lineHeight: 1.35 }, blurb),
        ]),
        el("div", { display: "flex", alignItems: "center", gap: 14 }, [
          el("div", { width: 18, height: 18, borderRadius: 999, background: COLOURS.accent }),
          el("div", { fontSize: 22, fontWeight: 500, color: COLOURS.ink, whiteSpace: "nowrap" }, `Free on Google Play · ${site.url.replace(/^https:\/\//, "").replace(/\/$/, "")}`),
        ]),
      ]),
    ]
  );
  const svg = await satori(tree as never, { width: W, height: H, fonts });
  const out = new Resvg(svg, { fitTo: { mode: "width", value: W } }).render().asPng();
  return new Response(new Uint8Array(out), { headers: { "Content-Type": "image/png" } });
}
