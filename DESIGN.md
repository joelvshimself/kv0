# kv0 design notes

kv0 sits with a hard worker through one day: wake, work, rest, go home, sleep.
The screen should feel like a sheet of kozo paper on a desk, read slowly, not like a dashboard.

## Principles

- **Ma (間).** Empty space is the layout. Sections are separated by space and a single
  hairline brushstroke, never by bordered cards.
- **One loud thing.** The hours left until your dip is the only large element. Everything
  else is quiet ink at reading size.
- **Ink, not colour.** Charts are drawn as ink washes (sumi at varying opacity). Vermilion
  appears in exactly one place per screen: the hanko seal that marks the dip on the time graph.
- **Texture is material.** The ground is unbleached washi with visible fibres and a few sumi
  specks, drawn procedurally so it never tiles.

## Colour

| Token     | Hex       | Role                                   |
|-----------|-----------|----------------------------------------|
| washi     | `#EDE6D9` | Paper ground                           |
| washiDeep | `#E2D8C6` | Fibres, chart track, picker plane      |
| sumi      | `#1A1410` | Primary ink: hero, headings            |
| inkSoft   | `#5A4838` | Secondary text, axis labels            |
| moss      | `#5D6B4A` | Good-recovery tint in the score chart  |
| shu       | `#A8342A` | Vermilion seal; the dip marker only    |

## Type

- **Display:** system serif (New York), light, tight tracking. Used for the hero number and
  the state sentence.
- **Body:** system sans, regular, sentence case. No all-caps labels, no eyebrows.
- Scale: 112 / 28 / 17 / 13. Hero numerals use monospaced digits so they don't jump on change.

## Layout

```
 state sentence (serif 28)

 2.5                 <- hero, left aligned, 112pt
 hours until your dip
 ~~~~~~~~ alertness wash, seal at dip ~~~~~~~~

 sleep time        | journey duration
 7h 20m            | 1h 05m

 sleep score, last 7 nights (ink bars)

 [ Working  v ]      <- paper plane, dropdown of journey states
```

Left aligned throughout, 24pt side margins, 40pt between sections.

## Motion

Only on state change: the hero crossfades with a numeric transition and the charts re-ink
with a slow ease (0.8s). Nothing moves on its own. Reduce Motion swaps everything to a plain fade.
