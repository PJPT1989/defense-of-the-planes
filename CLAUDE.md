# Defense of the Planes: notes for Claude

A tower defense game in **Godot 4.3** (GDScript, GL Compatibility renderer), themed on the
Phyrexian invasion of the Multiverse. It is Petr's project; he describes features in plain language
and expects them built, tested and shown with screenshots. `README.md` is the player-facing guide and
must stay accurate when gameplay changes. `docs/HISTORY.md` has every request Petr made and what was
built. Sister projects: `PJPT1989/aether-drift` and `PJPT1989/ashen-depths` (same tooling). The web
build is published on Petr's shop (`PJPT1989/tomano-collection-shop`, `hry-defense-of-the-planes.html`,
imported with its `tools/game_import.py`).

## Running and testing (cloud or Linux)
- `tools/setup_godot.sh` installs Godot 4.3 as `~/.local/bin/godot` and imports the project (the
  SessionStart hook in `.claude/settings.json` runs it in cloud sessions).
- `godot --headless --path . -- --simtest [--plane=N] [--verbose]` plays every plane with the
  autoplay bot without rendering and prints the result. Run it after any balance, wave or hero
  change; the bot must win every plane. `--verbose` prints each wave and the boss's life.
- `godot --headless --path . -- --waves` lists the generated waves of every plane.
- `tools/smoke_test.sh [dir]` runs `scripts/autotest.gd` under `xvfb-run`: title, campaign, codex,
  every plane, build menu, hero panel, bosses, pause and a full win. Look at the PNGs (default
  `/tmp/dotp-shots`). A good run ends with `AUTOTEST done` and has no `SCRIPT ERROR`.
- `xvfb-run -a godot --path . --rendering-driver opengl3 -- --lineup` renders every model
  (screenshots in `/tmp/dotp-lineup`).
- `tools/export_web.sh` builds `build/web/` (no-threads template). Test it in headless Chromium
  (`--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`).
- Always run Godot with `timeout`: a script error can leave it hanging.

## Design
- Lore source: *March of the Machine*. Plane names are kept; hero names, models and all text are
  original. Never copy card art, card text, character names or Wizards assets.
- Everything visual is generated from code: `MeshKit` with vertex colours and four shared materials
  (`Game.mat_solid`, `mat_glow`, `mat_gloss` for porcelain and metal, `mat_oil`). Models in
  `models.gd` and `props.gd`; portraits rendered once at start by `portraits.gd`.
- Data in `data.gd`: `TOWERS`, `ENEMIES`, `PLANES` (roads as polylines in Data units, theme, colours)
  and `waves_for(plane)`, which builds waves from a budget.
- `Battle.simulate(dt)` advances the game without rendering; the sim test, the smoke test and the
  title demo use it.
- Quality (`Game.quality`, L key, `user://settings.cfg`): as in Aether Drift; the web build drops to
  LOW once by itself if play starts slow.

## Code conventions
- GDScript with tabs, static types where the surrounding code has them, `##` doc comment at the top
  of each script. Nodes are built in code; `scenes/main.tscn` only holds `Main`.
- Web fonts have no fallback: use plain ASCII in titles and buttons.
