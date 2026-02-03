# lotty

Small Lottie loader + renderer for Nim, focused on producing Figdraw render lists.

Status: this is a minimal renderer. It currently supports filled ellipse groups (Lottie `gr` + `el` + `fl` + `tr`) and ignores other shape types. The API and coverage are still evolving.

## Install

This is a Nimble package. From the repo root:

```bash
nimble install
```

Dependencies (from `lotty.nimble`):
- Nim >= 2.0.10
- pixie >= 5.0.1
- chroma >= 0.2.7
- jsony
- figdraw (windy backend)

## Usage

Load a Lottie JSON file and render a frame to a Figdraw `Renders` list:

```nim
import lotty/loader
import lotty/render

let anim = loadLottieFile("data/bouncy_ball.json")
var renderer = initLottieMtsdfRenderer(anim)
let renders = renderer.renderLottieFrame(0.0)
```

You can then pass `renders` into a Figdraw renderer (see the example below).

## Example

There is a complete Windy example in `examples/figdraw_lottie_bouncy_ball.nim` that:
- opens a window
- loads `data/bouncy_ball.json`
- renders frames with `renderLottieFrame`

Run it with Nimble or directly with Nim:

```bash
nim r examples/figdraw_lottie_bouncy_ball.nim
```

If you prefer the Windex backend, build with `-d:useWindex`.

## Data

Example Lottie assets are in `data/`. The example expects `data/bouncy_ball.json` and `data/Ubuntu.ttf` to be present.

## License

MIT (see `lotty.nimble`).
