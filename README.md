# Defense of the Planes

A tower defense game built in Godot 4.3. The Phyrexian invasion has reached every world.
The Realmbreaker has driven its roots through the Multiverse and the horde pours out of the
rifts. Hold the line on seven planes with heroes from all of them, then carry the fight to
New Phyrexia and stop the Porcelain Mother.

Fan-made and unofficial. It is inspired by the *March of the Machine* storyline. All names of
characters, art, models and text in the game are original; plane names are kept for the setting.

## How to play
- Phyrexians march along the roads from the glowing rifts to your sanctum. Each one that gets
  through costs lives (bosses cost many). Lose all 20 lives and the plane falls.
- Click a free build spot to open the hero menu, then pick a hero to place there. Click a hero
  to upgrade it, change whom it aims at, or send it home for 70% of its cost. Every hero has five
  levels: Recruit, Veteran, Elite, then the costly late-game levels Exalted and Legendary, which
  add a turning crown of light around the tower.
- Killing Phyrexians earns mana. Calling the next wave early gives bonus mana.
- Each plane ends with a boss wave. Win with 18 or more lives for three stars, 10 or more for two.

## Modes
Every open plane can be played three ways:
- **Campaign**: the plane's set waves, ending with its boss. Stars, and the next plane opens.
- **Long Siege**: twice the waves. The plane's boss comes halfway and returns much stronger at the
  end; after the campaign's length every kind of Phyrexian joins in and the waves keep hardening.
- **Endless**: the horde never stops. A boss comes every ten waves (each one tougher). Your record
  of waves held is saved for each plane.

## Controls
| Key | Action |
| --- | --- |
| Left click | Build spot: hero menu. Hero: hero panel. |
| 1-9, 0, - | Build that hero on the selected spot (in menu order) |
| U / Delete or Backspace / T | Upgrade / sell / change aim of the selected hero |
| N or Enter | Call the next wave |
| Q | Halo Burst: heavy damage in a small area, click where |
| E | Stasis: every Phyrexian stops for 3 seconds (1.5 for bosses) |
| Tab or F | Game speed x1, x2, x4 |
| Esc or P | Pause |
| Right click | Cancel the menu or spell |
| WASD or arrows, right or middle drag, wheel | Pan and zoom |
| L | Graphics quality (Low, Medium, High) |
| M | Sound on/off |

## The campaign
| # | Plane | Battlefield | New |
| --- | --- | --- | --- |
| 1 | Dominaria | The Benalish Fields | Sunsworn Champion, Ember Prodigy, Timeweaver Sage |
| 2 | Kamigawa | Neon Streets of the Capital | Moonblade Ninja; flying Carrion Drakes |
| 3 | Zendikar | The Hedron Canyon | Hedron Lithomancer, Tidecaller; Oil Spitters |
| 4 | Ravnica | The Tenth District | Stormmind Dragon, Legion Warmarshal; Glistening Knights |
| 5 | Innistrad | The Moonlit Moor | Ghostblade Envoy; Vat Broodmothers |
| 6 | Kaldheim | The Frozen Fjord | Grovewarden, Sun-Rider; two rifts and tougher foes |
| 7 | New Phyrexia | The Realmbreaker's Root | The Porcelain Mother |

Each plane unlocks after the one before it. Stars are saved.

## Heroes
| Hero | Plane | Attack |
| --- | --- | --- |
| Sunsworn Champion | Dominaria | Spears of sunlight, extra damage to bosses |
| Ember Prodigy | Dominaria | Fireballs that splash and set foes burning |
| Timeweaver Sage | Dominaria | Time pulses that slow everything near him |
| Moonblade Ninja | Kamigawa | Very fast shuriken, hits flyers, two targets at level 3 |
| Hedron Lithomancer | Zendikar | Falling hedrons, long range, huge splash, no flyers |
| Tidecaller | Zendikar | Crashing waves that splash and throw foes back up the road, no flyers |
| Stormmind Dragon | Ravnica | Chain lightning |
| Legion Warmarshal | Ravnica | War banner: other heroes in range hit harder and faster |
| Ghostblade Envoy | Innistrad | Daggers that ignore armour and wards, execute at low life |
| Grovewarden | Kaldheim | Roots that hold walkers in place, no flyers |
| Sun-Rider | Kaldheim | Javelins from a raptor's back that crack armour and wards, no flyers |

## The Phyrexian horde
Scuttling Mites, Compleated Husks, Flayer Hounds, Oilback Brutes (heavy armour), Carrion Drakes
(fly), Oil Spitters (freeze heroes with oil), Glistening Knights (warded against magic) and Vat
Broodmothers (burst into mites). Bosses: the Realmbreaker Colossus, the Compleated Walker and the
Porcelain Mother, who spits oil on three heroes at once and calls up husks. The in-game Codex
describes all of them.

## Running it
Open the folder in Godot 4.3 and press Play, or build the browser version with
`tools/export_web.sh` (output in `build/web/`). See `CLAUDE.md` for the test tools.

## Files
| Path | What |
| --- | --- |
| `scripts/main.gd` | Screens: title (a live demo battle), campaign map, codex, how to play, results |
| `scripts/battle.gd` | One defense: waves, building, targeting, attacks, spells, the autoplay bot |
| `scripts/data.gd` | Heroes, Phyrexians, planes and the wave generator |
| `scripts/level.gd` | Roads, build spots, ground, scenery and lighting of a plane |
| `scripts/models.gd`, `scripts/props.gd` | Procedural 3D models of heroes, Phyrexians and scenery |
| `scripts/hud.gd`, `scripts/ui.gd` | In-battle interface and shared UI pieces |
| `scripts/portraits.gd` | Renders hero and Phyrexian portraits for menus |
| `scripts/game.gd` | Autoload: settings, progress, fonts, materials, sounds |
| `shaders/` | Sky, ground, glossy porcelain, oil and glow |
| `tools/` | Godot setup, smoke test, web export, model lineup, hero close-ups and wave listing |
