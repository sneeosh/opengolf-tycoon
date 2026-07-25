# Visual asset manifest

Record every AI-generated or materially AI-edited runtime asset here. Do not record rejected candidates under `.visual-pipeline/`.

| Asset family | Runtime path | In-game canvas | Source/reference | Provider | Cost | Status | Notes |
|---|---|---:|---|---|---:|---|---|
| Existing terrain atlas | `assets/tilesets/terrain_tileset.png` | 448x64 | Pre-existing project asset | — | — | Baseline | Seven 64x64 atlas cells; preserve terrain indices. |
| Parkland clubhouse | `assets/sprites/buildings/clubhouse_1.png` | 200x160 | `visual_pipeline/parkland-generation-record.json` | Gemini 3.1 Flash Image Preview | $0.07 | Integrated | New projection, material, edge, and lighting reference; preserves bottom-center contract. |
| Existing golfer | `assets/sprites/golfer/east.png` | 48x48 | Pre-existing project asset | — | — | Baseline | Preserve feet anchor and animation folder contract. |
| Parkland buildings | `assets/sprites/buildings/{pro_shop,snack_bar,restroom,bench,driving_range}.png` | Existing per-slot canvases | `visual_pipeline/parkland-generation-record.json` | Gemini 3.1 Flash Image Preview | $0.42 | Integrated | Shared cream, cedar, and deep-green material family. Old window-glow coordinates disabled for replaced art. |
| Parkland trees | `assets/sprites/trees/{oak,pine}.png` | 54x84; 48x80 | `visual_pipeline/parkland-generation-record.json` | Gemini 3.1 Flash Image Preview | $0.21 | Integrated | Oak rerolled for a taller gameplay silhouette; entity ground offsets updated. |
| Parkland props | `assets/sprites/rocks/small.png`, `assets/sprites/tiles/flower_bed.png`, `assets/sprites/flag/flag.png`, `assets/sprites/golf_cart/golf_cart.png` | Existing per-slot canvases | `visual_pipeline/parkland-generation-record.json` | Gemini 3.1 Flash Image Preview | $0.28 | Integrated | Transparent drop-in replacements; small-rock ground offset updated. |
| Parkland golfer motion proof | Not promoted | 480p, 1-second references | `visual_pipeline/parkland-generation-record.json` | Gemini 3.1 Flash Image Preview + Grok Imagine Video | $0.34 | Proof only | Two tier references plus walk/swing clips. Beginner walk rejected for club-position drift; runtime frame contracts remain unchanged. |
| Parkland terrain material board | Not promoted | 2K reference board | `visual_pipeline/parkland-generation-record.json` | Gemini 3.1 Flash Image Preview | $0.10 | Reference only | Used to assess material separation; not a contract-safe 448x64 atlas. |

For each approved generated asset, include the exact reference image or prompt-record path, provider/model, paid cost, final canvas, and any import/anchor changes.

Parkland asset-set total: approximately **$1.42**, including the $0.07 clubhouse generated before the final slice approval. The approved slice work itself was approximately **$1.35**, below its $1.40 cap. Generated candidates and video frames remain under ignored `.visual-pipeline/`; only reviewed runtime assets are committed.
