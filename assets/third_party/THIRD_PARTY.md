# Third-Party Asset Manifest

Only selected production files are stored here. Download archives and unused source files stay under `build/vendor/` and are not part of the game.

## Kenney Furniture Kit

- Source: https://kenney.nl/assets/furniture-kit
- Version: 2.0
- License: Creative Commons Zero (CC0 1.0)
- Original archive: `kenney_furniture-kit.zip`
- Imported format: GLB
- Selected files: `bathroomSinkSquare`, `bathtub`, `bear`, `chairDesk`, `desk`, `doorwayOpen`, `plantSmall2`, `radio`, and `showerRound`.
- Intended use: dreamcore familiar-object dressing, poolrooms fixtures, and later residential/office branches.
- Gameplay rule: these models are visual children only. Collision and interaction remain on project-owned scene roots.

## Poly Haven Interior Tiles

- Source: https://polyhaven.com/a/interior_tiles
- Author: Charlotte Baglioni
- License: Creative Commons Zero (CC0 1.0)
- Imported files: 1K JPG diffuse and OpenGL normal map.
- Intended use: poolrooms wall and floor modules.
- Web budget: use the 1K source maps and Godot texture compression; do not import the 8K or 16K variants into the project.

## Quaternius Ultimate Monsters

- Source: https://quaternius.com/packs/ultimatemonsters.html
- Author: Quaternius
- License: Creative Commons Zero (CC0 1.0)
- Imported format: animated FBX plus the supplied shared texture atlas.
- Selected candidates: `Alien`, `Demon`, and `Orc_Skull`; the full pack remains outside the project.
- Intended use: visual studies for the Listener, ordinary chaser, and Watcher before choosing final production models.
- Gameplay rule: models and animation players are visual children only. Project-owned roots retain scripts, collision, navigation, multiplayer paths, warning effects, and hit rules.
