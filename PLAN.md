# Tilt - game design and build plan

The living design document: what we are building, how the code is organised, and the order we build it
in. When a decision changes, update this file. Shared working rules live in the workspace `CLAUDE.md`;
the systems lessons live in `MATH.md` next to this file.

## 1. Vision

One paragraph a stranger could repeat back. What the player does, and why it is fun.

### Design pillars

1. **Pillar.** One sentence of why.
2. **Pillar.**
3. **Pillar.**

### Target and constraints

- Platform: Android first (Google Play), portrait. Web build is a preview channel, not the target.
- Engine: Godot 4.7, GL Compatibility renderer.
- Audience: all ages unless decided otherwise.
- Art: generated or CC0 packs, see `CREDITS.md`.
- Monetization: decided in section 6, built last, behind desktop-safe stubs.

### What this is not

Name the tempting scope this game refuses.

## 2. Core mechanics

The verbs, the controls (touch and desktop mirror), and what is simulated versus scripted.

## 3. Difficulty

The scalar or curve that drives it, and the fairness invariant a test will assert.

## 4. Screens

Boot, menu, game, HUD, pause, game over, settings. Retry must be one tap.

## 5. Monetization

Rewarded first, interstitials capped, cosmetics only. Nothing that changes difficulty.

## 6. Project architecture

```
autoload/    event_bus.gd, save.gd, audio.gd
scenes/      game/, ui/
scripts/     pure logic, unit tested without the scene tree
resources/   .tres data
assets/      shipped art, audio, fonts (generated output is never hand-edited)
tools/       generators, harnesses, probes
tests/       run_tests.gd
```

## 7. Milestones

One milestone is playable before the next starts.

- **M0 - Is it fun**: the core verb in a grey box, on a real phone, with measured numbers. Go or no-go.
- **M1 - The one perfect minute**: the full loop with instant retry.
- **M2 - It looks like a game**: lighting, characters, props, font, audio.
- **M3 - Feel**: particles, shake, hit stop, haptics.
- **M4 - Meta**: save, settings, menus.
- **M5 - Monetization**: stubs wired to real plugins.
- **M6 - Balance**: tune against playtest data.
- **M7 - Store prep**: icon, screenshots, listing, privacy policy.
- **M8 - Ship**: Android toolchain, closed test, production.

## 8. What would kill this

Named up front so we notice it happening.
