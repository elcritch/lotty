import std/[math, options, os, unittest]

import pkg/pixie
import pkg/sdfy/msdfgen

import lotty/anim
import lotty/paths
import lotty/types

const
  imageSize = 192
  pxRange = 4.0

proc staticProp[T](val: T): LottieProperty[T] =
  LottieProperty[T](a: lakStatic, kValue: val)

proc optProp[T](val: T): Option[LottieProperty[T]] =
  some(staticProp(val))

proc vec2FromSeq(vals: seq[float32], fallback: Vec2): Vec2 =
  if vals.len >= 2:
    vec2(vals[0], vals[1])
  elif vals.len == 1:
    vec2(vals[0], vals[0])
  else:
    fallback

proc pathFromShape(shape: LottieShape): Path =
  let frame = 0.0'f32
  let center =
    vec2FromSeq(valueAtOr(shape.p, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  let size = vec2FromSeq(valueAtOr(shape.s, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  let roundness = valueAtOr(shape.r, frame, 0.0'f32)
  var path = newPath()

  case shape.ty
  of lstEllipse:
    path.ellipse(center, size.x / 2.0'f32, size.y / 2.0'f32)
  of lstRect:
    let topLeft = center - vec2(size.x / 2.0'f32, size.y / 2.0'f32)
    if roundness > 0.0'f32:
      path.roundedRect(
        topLeft.x, topLeft.y, size.x, size.y, roundness, roundness, roundness, roundness
      )
    else:
      path.rect(topLeft.x, topLeft.y, size.x, size.y)
  of lstStar:
    let points = max(3, valueAtOr(shape.points, frame, 0.0'f32).round().int)
    let outerRadius = valueAtOr(shape.outerRadius, frame, 0.0'f32)
    let innerRadius = valueAtOr(shape.innerRadius, frame, 0.0'f32)
    let rotation = valueAtOr(shape.r, frame, 0.0'f32) * (PI / 180.0'f32)
    let starType = shape.starType.get(1.0'f32)
    let isPolygon = starType >= 2.0'f32 or innerRadius <= 0.0'f32

    if points > 2 and outerRadius > 0.0'f32:
      if isPolygon:
        for i in 0 ..< points:
          let angle = rotation + (i.float32 * 2.0'f32 * PI / points.float32)
          let pt = vec2(
            center.x + sin(angle) * outerRadius, center.y - cos(angle) * outerRadius
          )
          if i == 0:
            path.moveTo(pt)
          else:
            path.lineTo(pt)
        path.closePath()
      else:
        let total = points * 2
        for i in 0 ..< total:
          let radius = if i mod 2 == 0: outerRadius else: innerRadius
          let angle = rotation + (i.float32 * PI / points.float32)
          let pt = vec2(center.x + sin(angle) * radius, center.y - cos(angle) * radius)
          if i == 0:
            path.moveTo(pt)
          else:
            path.lineTo(pt)
        path.closePath()
  of lstPath:
    let pathData = valueAtOr(shape.path, frame, default(LottiePath))
    path = pathFromLottiePath(pathData)
  else:
    discard

  path

proc writeShape(outDir: string, name: string, shape: LottieShape, size: int) =
  let path = pathFromShape(shape)
  let mtsdf = generateMtsdfPath(path, size, size, pxRange)
  let outPath = outDir / name
  mtsdf.image.writeFile(outPath)
  check fileExists(outPath)

proc writeShapeMsdf(outDir: string, name: string, shape: LottieShape, size: int) =
  let path = pathFromShape(shape)
  let msdf = generateMsdfPath(path, size, size, pxRange)
  let outPath = outDir / name
  msdf.image.writeFile(outPath)
  check fileExists(outPath)

proc writeShapeRendered(outDir: string, name: string, shape: LottieShape, size: int) =
  let path = pathFromShape(shape)
  let mtsdf = generateMtsdfPath(path, size, size, pxRange)
  let rendered = renderMsdf(mtsdf)
  let outPath = outDir / name
  rendered.writeFile(outPath)
  check fileExists(outPath)

proc writeShapeMsdfRendered(
    outDir: string, name: string, shape: LottieShape, size: int
) =
  let path = pathFromShape(shape)
  let msdf = generateMsdfPath(path, size, size, pxRange)
  let rendered = renderMsdf(msdf)
  let outPath = outDir / name
  rendered.writeFile(outPath)
  check fileExists(outPath)

proc writeShape(outDir: string, name: string, shape: LottieShape) =
  writeShape(outDir, name, shape, imageSize)

proc writeShapeRendered(outDir: string, name: string, shape: LottieShape) =
  writeShapeRendered(outDir, name, shape, imageSize)

proc assertImageMatches(
    outDir: string,
    actualPath: string,
    expectedPath: string,
    diffName: string,
    maxDiff: float32,
) =
  let expected = readImage(expectedPath)
  let actual = readImage(actualPath)
  let (diffScore, diffImg) = diff(expected, actual)
  if diffScore > maxDiff:
    let diffPath = outDir / diffName
    diffImg.writeFile(diffPath)
  check diffScore <= maxDiff

suite "lottie mtsdf basic shapes":
  test "generates mtsdf images for common shapes":
    let outDir = getCurrentDir() / "tests" / "output"
    createDir(outDir)
    let expectedDir = getCurrentDir() / "tests" / "expected"

    let ellipse = LottieShape(
      ty: lstEllipse,
      p: optProp(@[96.0'f32, 96.0'f32]),
      s: optProp(@[140.0'f32, 90.0'f32]),
    )
    writeShape(outDir, "lottie_mtsdf_ellipse.png", ellipse)

    let rect = LottieShape(
      ty: lstRect,
      p: optProp(@[96.0'f32, 96.0'f32]),
      s: optProp(@[150.0'f32, 90.0'f32]),
      r: optProp(0.0'f32),
    )
    writeShape(outDir, "lottie_mtsdf_rect.png", rect)

    let roundRect = LottieShape(
      ty: lstRect,
      p: optProp(@[96.0'f32, 96.0'f32]),
      s: optProp(@[150.0'f32, 90.0'f32]),
      r: optProp(18.0'f32),
    )
    writeShape(outDir, "lottie_mtsdf_round_rect.png", roundRect)

    let star = LottieShape(
      ty: lstStar,
      p: optProp(@[96.0'f32, 96.0'f32]),
      points: optProp(5.0'f32),
      outerRadius: optProp(70.0'f32),
      innerRadius: optProp(32.0'f32),
      starType: some(1.0'f32),
      r: optProp(0.0'f32),
    )
    writeShape(outDir, "lottie_mtsdf_star.png", star)

    let polygon = LottieShape(
      ty: lstStar,
      p: optProp(@[96.0'f32, 96.0'f32]),
      points: optProp(6.0'f32),
      outerRadius: optProp(70.0'f32),
      innerRadius: optProp(0.0'f32),
      starType: some(2.0'f32),
      r: optProp(0.0'f32),
    )
    writeShape(outDir, "lottie_mtsdf_polygon.png", polygon)

    let pathData = LottiePath(
      v:
        @[
          @[96.0'f32, 24.0'f32],
          @[168.0'f32, 96.0'f32],
          @[96.0'f32, 168.0'f32],
          @[24.0'f32, 96.0'f32],
        ],
      o:
        @[
          @[40.0'f32, 0.0'f32],
          @[0.0'f32, 40.0'f32],
          @[-40.0'f32, 0.0'f32],
          @[0.0'f32, -40.0'f32],
        ],
      i:
        @[
          @[0.0'f32, -40.0'f32],
          @[40.0'f32, 0.0'f32],
          @[0.0'f32, 40.0'f32],
          @[-40.0'f32, 0.0'f32],
        ],
      c: true,
    )

    let genericPath = LottieShape(ty: lstPath, path: optProp(pathData))
    writeShape(outDir, "lottie_mtsdf_path.png", genericPath)

    let heartPath = LottiePath(
      v:
        @[
          @[237.376'f32, 436.245'f32],
          @[238.15'f32, 437.221'f32],
          @[437.481'f32, 69.515'f32],
          @[238.15'f32, 100.468'f32],
          @[237.376'f32, 100.468'f32],
          @[38.045'f32, 69.515'f32],
        ],
      o:
        @[
          @[0.0'f32, 0.0'f32],
          @[210.94'f32, -85.154'f32],
          @[-92.899'f32, -85.154'f32],
          @[0.0'f32, 0.0'f32],
          @[0.0'f32, 0.0'f32],
          @[-92.889'f32, 85.143'f32],
        ],
      i:
        @[
          @[-210.939'f32, -85.153'f32],
          @[0.0'f32, 0.0'f32],
          @[92.89'f32, 85.153'f32],
          @[0.0'f32, 0.0'f32],
          @[0.0'f32, 0.0'f32],
          @[92.891'f32, -85.154'f32],
        ],
      c: true,
    )

    let heartShape = LottieShape(ty: lstPath, path: optProp(heartPath))
    let heartSize = 128
    writeShapeMsdf(outDir, "lottie_mtsdf_heart.png", heartShape, heartSize)
    writeShapeMsdfRendered(
      outDir, "lottie_mtsdf_heart_render.png", heartShape, heartSize
    )

    let expectedField = expectedDir / "msdf_heart_field.png"
    let expectedRender = expectedDir / "msdf_heart_render.png"
    let actualField = outDir / "lottie_mtsdf_heart.png"
    let actualRender = outDir / "lottie_mtsdf_heart_render.png"

    assertImageMatches(
      outDir, actualField, expectedField, "lottie_mtsdf_heart.diff.png", 0.01'f32
    )
    assertImageMatches(
      outDir, actualRender, expectedRender, "lottie_mtsdf_heart_render.diff.png",
      0.01'f32,
    )
