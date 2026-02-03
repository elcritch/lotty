import std/[options, os, unittest]

import lotty/anim
import lotty/loader
import figdraw/commons

suite "lottie loading":
  test "loads and animates rotation":
    setFigDataDir(getCurrentDir() / "data")
    let anim = loadLottieFile(figDataDir() / "loading.json")
    check anim.layers.len == 4

    let layer = anim.layers[0]
    check layer.ks.r.isSome

    let r0 = valueAtOr(layer.ks.r, 84.0'f32, -1.0'f32)
    check abs(r0 - 0.0'f32) < 0.01'f32

    let r1 = valueAtOr(layer.ks.r, 150.0'f32, -1.0'f32)
    check abs(r1 - 360.0'f32) < 0.01'f32
