// How this site counts visits, from site.analytics: Cloudflare's own injection, Head's beacon, or not at all.
import { site } from "../site.config";

const { cloudflare, token } = site.analytics;

/** The site token Head loads Cloudflare's beacon with; empty when Cloudflare injects it or nothing counts. */
export const beaconToken = cloudflare === "token" ? token : "";

/** Cloudflare adds the beacon itself, to every page on the proxied hostname, the game's /play/ included. */
export const injected = cloudflare === "auto";

/** Whether visits are counted at all, which the Privacy page then describes. */
export const countsVisits = injected || beaconToken !== "";
