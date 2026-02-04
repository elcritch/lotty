import std/[os, unittest]

import chroma
import pkg/pixie

import lotty/loader
import lotty/render
import figdraw/common/imgutils
import figdraw/fignodes
import figdraw/commons
import figdraw/windyshim
import ../deps/figdraw/tests/opengl_test_utils

suite "lottie bouncy ball stroke":
  test "builds mtsdf stroke style at keyframes":
    when not compiles(
      (
        block:
          var tmp = Fig()
          tmp.mtsdfImage.strokeWeight = 1.0'f32
      )
    ):
      skip()
      return

    setFigDataDir(getCurrentDir() / "data")
    let anim = loadLottieFile(figDataDir() / "bouncy_ball.json")
    var renderer = initLottieMtsdfRenderer(anim)

    let renders0 = renderer.renderLottieFrame(0.0'f32)
    let list0 = renders0.layers[0.ZLevel]
    check list0.nodes.len == 2
    let node0 = list0.nodes[1]
    check node0.kind == nkMtsdfImage
    check hasImage(node0.mtsdfImage.id)

    var stroke0 = node0
    stroke0.fill = rgba(0, 0, 0, 0).color
    stroke0.mtsdfImage.color = rgba(24, 24, 24, 255).color
    stroke0.mtsdfImage.strokeWeight = 6.0'f32
    check stroke0.mtsdfImage.strokeWeight == 6.0'f32

    let renders60 = renderer.renderLottieFrame(60.0'f32)
    let list60 = renders60.layers[0.ZLevel]
    let node60 = list60.nodes[1]
    check node60.kind == nkMtsdfImage

    var stroke60 = node60
    stroke60.fill = rgba(0, 0, 0, 0).color
    stroke60.mtsdfImage.color = rgba(24, 24, 24, 255).color
    stroke60.mtsdfImage.strokeWeight = 6.0'f32
    check stroke60.mtsdfImage.strokeWeight == 6.0'f32

    let outDir = ensureTestOutputDir()
    let outPath = outDir / "lottie_bouncy_ball_stroke.png"
    if fileExists(outPath):
      removeFile(outPath)

    block renderOnce:
      var img: Image
      try:
        img = renderAndScreenshotOnce(
          makeRenders = proc(w, h: float32): Renders =
            var renders = renderer.renderLottieFrame(0.0'f32)
            let list = renders.layers[0.ZLevel]
            if list.nodes.len > 1:
              let node = list.nodes[1]
              if node.kind == nkMtsdfImage:
                var stroked = node
                stroked.fill = rgba(0, 0, 0, 0).color
                stroked.mtsdfImage.color = rgba(24, 24, 24, 255).color
                stroked.mtsdfImage.strokeWeight = 6.0'f32
                renders.layers[0.ZLevel].nodes[1] = stroked
            renders,
          outputPath = outPath,
          title = "figdraw test: lottie bouncy ball stroke",
        )
      except WindyError:
        skip()
        break renderOnce

      check fileExists(outPath)
      check getFileSize(outPath) > 0
