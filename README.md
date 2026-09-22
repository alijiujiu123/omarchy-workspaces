# omarchy-workspaces

The bar's workspace numbers, **derived per screen**: "3" means the third workspace *of the screen
you are on*, not the workspace with id 3. A Quickshell bar widget for omarchy-shell.

```bash
omarchy plugin add https://github.com/alijiujiu123/omarchy-workspaces --enable
```

## Why

The built-in `omarchy.workspaces` widget carried two hardcoded assumptions — a fixed row of five
numbers and `id <= 10` — on top of a workspace id space that is global and shared between monitors.
On a machine with two screens that produced three wrong behaviours at once: the same ten numbers
were drawn on both screens, a workspace past the tenth could not be seen at all, and clicking "3"
went to whichever screen happened to own id 3 (this machine's own numbering is interleaved:
`eDP-1` owns 1,2,3,7,8,9 and `HDMI-A-1` owns 4,5,6 plus 10..16).

This widget derives everything from live state instead, following the five invariants of the
`workspaces` module in [omarchy-setup-kit](https://github.com/alijiujiu123/omarchy-setup-kit)
(`docs/MANUAL-STEPS.md`, "Workspace addresses"):

1. a workspace's screen comes from live state (`workspace.monitor`), never from an id range;
2. its **ordinal** is its rank among that screen's workspaces sorted by id — so closing a workspace
   moves the ones behind it up, and unplugging a screen re-derives its numbers;
3. a workspace occupies an ordinal when it has windows, is persistent, or is the one you are on;
4. nothing crosses screens: the filter is the focused monitor, which is what `SUPER + digit`, the
   wheel, the tachpad gestures, the overview and this widget all mean by "the n-th workspace";
5. no count is hardcoded — the slots *are* the workspaces that exist.

Labels are `1..9` and `0` for the tenth (the digits laid out as on a keyboard, matching the
overview's card labels and `SUPER + 0`). Past the tenth the trailing chip shows `+N` for the rest
and opens the overview when clicked, because the overview is the only surface that can show — and
now also *create* (its trailing "+" card) — workspaces beyond the digits.

## Provenance

Cloned from omarchy's built-in `omarchy.workspaces` (`omarchy plugin clone omarchy.workspaces`,
2026-09-22, omarchy 4.0.3-1), so the manifest keeps `omarchy.clonedFrom` and the visual language
(`BarWidget` + `WidgetButton` + the focused-state glyph) is unchanged on purpose: it is the same
widget the bar already draws, with the addressing corrected. Omarchy is the upstream for the widget
that this file started as; there is no separate upstream repository to track, so nothing is pushed
back there.

## Verifying it

The bar should show this screen's workspaces, in id order, numbered from 1:

* switch the focused screen (or move the pointer to the other one, `input:follow_mouse = 1`) — the
  numbers change to that screen's set and the other screen's workspaces disappear from the bar;
* on this machine's `HDMI-A-1` that is `1..9,0` for ids 4,5,6,10..16 — ten slots, where the built-in
  widget drew the same ten numbers on both screens;
* create a workspace with the overview's trailing "+" card: it is persistent, so it stays a slot
  after you leave it, and the bar grows an 11th number (or starts the `+N` chip).
