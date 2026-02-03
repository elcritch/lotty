import std/[math, options, os, unittest]

import pkg/pixie
import pkg/sdfy/msdfgen

import lotty/anim
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

proc pathFromLottiePath(pathData: LottiePath): Path =
  var path = newPath()
  if pathData.v.len == 0:
    return path

  let first = vec2FromSeq(pathData.v[0], vec2(0.0, 0.0))
  path.moveTo(first)

  let lastIndex = pathData.v.len - 1
  for i in 0 ..< lastIndex:
    let v0 = vec2FromSeq(pathData.v[i], vec2(0.0, 0.0))
    let v1 = vec2FromSeq(pathData.v[i + 1], vec2(0.0, 0.0))
    let o0 =
      if i < pathData.o.len:
        vec2FromSeq(pathData.o[i], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)
    let i1 =
      if i + 1 < pathData.i.len:
        vec2FromSeq(pathData.i[i + 1], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)

    path.bezierCurveTo(v0 + o0, v1 + i1, v1)

  if pathData.c:
    let vLast = vec2FromSeq(pathData.v[lastIndex], vec2(0.0, 0.0))
    let vFirst = vec2FromSeq(pathData.v[0], vec2(0.0, 0.0))
    let oLast =
      if lastIndex < pathData.o.len:
        vec2FromSeq(pathData.o[lastIndex], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)
    let iFirst =
      if 0 < pathData.i.len:
        vec2FromSeq(pathData.i[0], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)

    path.bezierCurveTo(vLast + oLast, vFirst + iFirst, vFirst)
    path.closePath()

  path

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

proc writeShape(outDir: string, name: string, shape: LottieShape) =
  let path = pathFromShape(shape)
  let mtsdf = generateMtsdfPath(path, imageSize, imageSize, pxRange)
  let outPath = outDir / name
  mtsdf.image.writeFile(outPath)
  check fileExists(outPath)

suite "lottie mtsdf basic shapes":
  test "generates mtsdf images for common shapes":
    let outDir = getCurrentDir() / "tests" / "output"
    createDir(outDir)

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
          @[96.0'f32, 140.0'f32],
          @[60.0'f32, 80.0'f32],
          @[96.0'f32, 60.0'f32],
          @[132.0'f32, 80.0'f32],
        ],
      o:
        @[
          @[0.0'f32, -20.0'f32],
          @[0.0'f32, -30.0'f32],
          @[6.0'f32, -20.0'f32],
          @[0.0'f32, 30.0'f32],
        ],
      i:
        @[
          @[0.0'f32, -20.0'f32],
          @[0.0'f32, 30.0'f32],
          @[-6.0'f32, -20.0'f32],
          @[0.0'f32, -30.0'f32],
        ],
      c: true,
    )

    let heartShape = LottieShape(ty: lstPath, path: optProp(heartPath))
    writeShape(outDir, "lottie_mtsdf_heart.png", heartShape)
