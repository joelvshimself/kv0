# kv0 design notes

kv0's visual language is adapted from [nova30.lat](https://nova30.lat) (Hotmart's Nova30):
a night sky where a few bright bodies light up everything around them. In kv0 the bright body
is your energy: the hours until your next dip.

## Principles

- **One star.** The hero number sits inside dashed orbits and is the only large element.
  Everything else is quiet bone text at reading size.
- **Orange is light.** Orange marks what is live: the planet tracking the time of day, the dip
  on the alertness curve, last night's score bar, the dot in the picker.
- **Glass over void.** Secondary content lives on frosted cards (20pt radius, white at 3%,
  hairline edge) floating over the near-black sky.
- **Constellation.** The background is a seeded starfield with two faint radial glows,
  rust at upper left and ember at lower right, as on the Nova site.

## Colour

| Token    | Hex       | Role                                        |
|----------|-----------|---------------------------------------------|
| void     | `#0D0D0D` | Sky / background                            |
| surface  | `#1C1C1C` | Picker plane, grey moon                     |
| bone     | `#F5F3EF` | All text and the alertness line             |
| orange   | `#FF4000` | Live accent: dip, last night, orbits at 35% |
| ember    | `#FF5733` | Planet, highlighted labels, glow            |
| rust     | `#B85C3E` | Radial glow in the background               |
| muted    | `#666666` | Axis labels, footnotes                      |
| hairline | white 10% | Card and pill borders                       |

## Type

Space Grotesk (OFL, bundled in `kv0/Resources/Fonts`) stands in for the proprietary
Hotmart Display and Hotmart Sans. Display sizes use Nova's -0.04em tracking.

Scale: 140 hero / 34 metric / 30 sentence / 17 body / 13 caption. Numerals are monospaced so
values don't jump when they change.

## Shapes

- Pills: fully rounded (Nova uses 50px), used for the state picker.
- Cards: 20pt continuous corners.
- Orbits: 1pt dashed rings, `[3, 5]` dash.

## Motion

On state change the sentence lights up character by character (Nova's headline reveal), the
hero number rolls with a numeric transition, and the planet glides to its new position over
0.8s. Nothing moves on its own. Reduce Motion shows the sentence immediately and shortens
every transition to a 0.2s fade.
