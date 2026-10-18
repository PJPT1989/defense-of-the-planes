# History

## Round 1: the first version
**Request (Petr):** "I want to start creating another game into the eshop. It will be tower
defence. Again, theme is Magic the gathering. This time its about Phyrexia invasion (march of
machines). Study the march of machines lore and come up with tower defense game that follows this
theme. Towers are significant characters from all the planes and running creatures are phyrexian
hordes. So the models needs to follow this logic. Lets use godot engine again. Name of the game -
Defense of the planes." Also: sharp graphics and detailed models, the same Low/Medium/High quality
levels as Aether Drift, and a page in the shop's Hry section.

**Built:**
- A seven-plane campaign following the invasion (Dominaria, Kamigawa, Zendikar, Ravnica, Innistrad,
  Kaldheim, then New Phyrexia), each with its own battlefield, scenery, sky and colours, and a boss.
- Eight heroes, one or more per plane, each nodding to a well-known character of that plane but
  with an original name, look and text (Sunsworn Champion, Ember Prodigy, Timeweaver Sage,
  Moonblade Ninja, Hedron Lithomancer, Stormmind Dragon, Ghostblade Envoy, Grovewarden). Each has
  three levels with visibly bigger models.
- Eight Phyrexian foes plus three bosses, built as porcelain, steel and red sinew with oil.
- Two spells (Halo Burst, Stasis), upgrades, selling, aim modes, early wave calls, speed up.
- Title screen with a live demo battle, campaign map with stars, Codex, how to play, results.
- Balance checked with a simulated player (`--simtest`) that wins every plane; the finale is the
  hardest. All art is generated in code.

## Round 2: a bigger late game
**Request (Petr):** "Introduce option to have more waves in a map and also more tower upgrades
and/or more tower types so that game can scale into bigger lategame"

**Built:**
- Two new modes on every open plane: **Long Siege** (twice the waves, the boss halfway and a much
  stronger one at the end) and **Endless** (a boss every ten waves, cycling through all three, each
  tougher; the record of waves held is saved per plane). Past the campaign's length every foe joins
  in, more special groups come, groups that would outgrow their size cap get tougher foes instead
  (paying a little more mana, though late bounties are cut to 55%), and every wave hardens by 6% on top of the usual growth.
- Two more hero levels, **Exalted** and **Legendary** (five in all), each about +50% damage, with
  longer range and bigger effects (the ninja throws at three targets, the dragon's lightning jumps
  to nine). They cost two and three times the third level, so they are a late-game mana sink.
  Levels 4 and 5 add a turning crown of gold rings, runes and gems around the tower.
- Three new heroes (eleven in all): the **Tidecaller** (Zendikar; waves that throw foes back up
  the road), the **Legion Warmarshal** (Ravnica; a banner that makes other heroes in range hit
  harder and faster) and the **Sun-Rider** (Kaldheim; javelins thrown from a raptor that crack
  armour and wards). Build keys are now 1-9, 0 and -.
- Game speed x4, Halo Burst grows with the waves, the simulated player weighs damage types against
  the coming waves, and `--simtest --mode=1|2` plays the long modes.
