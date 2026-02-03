import std/[hashes, math, options]

import pkg/pixie
import pkg/sdfy/msdfgen

import figdraw/fignodes
import figdraw/common/imgutils

import ./types
import ./paths
import ./anim

type
  LottieResolvedTransform = object
    anchor: Vec2
    position: Vec2
    scale: Vec2
    rotation: float32
    opacity: float32

  LottieMtsdfRenderer* = object
    animation*: LottieAnimation
    pxRange*: float32
    sdThreshold*: float32
    maxSdfSize*: float32

proc vec2FromSeq(vals: seq[float32], fallback: Vec2): Vec2 =
  if vals.len >= 2:
    vec2(vals[0], vals[1])
  elif vals.len == 1:
    vec2(vals[0], vals[0])
  else:
    fallback

proc colorFromSeq(vals: seq[float32], alpha: float32): Color =
  if vals.len >= 3:
    color(vals[0], vals[1], vals[2], alpha)
  else:
    color(0.0'f32, 0.0'f32, 0.0'f32, alpha)

proc resolvedTransform(tr: LottieTransform, frame: float32): LottieResolvedTransform =
  result.anchor =
    vec2FromSeq(valueAtOr(tr.a, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  result.position =
    vec2FromSeq(valueAtOr(tr.p, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  result.scale =
    vec2FromSeq(valueAtOr(tr.s, frame, @[100.0'f32, 100.0'f32]), vec2(100.0, 100.0))
  result.rotation = valueAtOr(tr.r, frame, 0.0'f32)
  result.opacity = valueAtOr(tr.o, frame, 100.0'f32)

proc resolvedTransformFromShape(
    shape: LottieShape, frame: float32
): LottieResolvedTransform =
  result.anchor =
    vec2FromSeq(valueAtOr(shape.a, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  result.position =
    vec2FromSeq(valueAtOr(shape.p, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  result.scale =
    vec2FromSeq(valueAtOr(shape.s, frame, @[100.0'f32, 100.0'f32]), vec2(100.0, 100.0))
  result.rotation = valueAtOr(shape.r, frame, 0.0'f32)
  result.opacity = valueAtOr(shape.o, frame, 100.0'f32)

proc applyTransform(
    center, size: Vec2, transform: LottieResolvedTransform
): tuple[center, size: Vec2, opacity: float32] =
  let scale = vec2(transform.scale.x / 100.0'f32, transform.scale.y / 100.0'f32)
  let local = center - transform.anchor
  let angle = transform.rotation * (PI / 180.0'f32)
  let cosA = cos(angle)
  let sinA = sin(angle)
  let scaled = vec2(local.x * scale.x, local.y * scale.y)
  let rotated =
    vec2(scaled.x * cosA - scaled.y * sinA, scaled.x * sinA + scaled.y * cosA)
  result.center = transform.position + rotated
  result.size = vec2(size.x * scale.x, size.y * scale.y)
  result.opacity = transform.opacity / 100.0'f32

proc ellipseImageId(size: Vec2): ImageId =
  let key = "lottie:ellipse:" & $size.x & "x" & $size.y
  imgId(key)

proc ensureEllipseMtsdf(size: Vec2, pxRange: float32): ImageId =
  let id = ellipseImageId(size)
  if hasImage(id):
    return id

  let width = max(1, size.x.round().int)
  let height = max(1, size.y.round().int)
  var path = newPath()
  path.ellipse(
    vec2(size.x / 2.0'f32, size.y / 2.0'f32), size.x / 2.0'f32, size.y / 2.0'f32
  )

  echo "WXH: ", width, " x ", height
  let mtsdf = generateMtsdfPath(path, width, height, pxRange.float64)
  loadImage(id, mtsdf.image)
  id

proc pathImageId(path: Path, size: Vec2): ImageId =
  let key = "lottie:path:" & $hash($path) & ":" & $size.x & "x" & $size.y
  imgId(key)

proc ensurePathMtsdf(path: Path, size: Vec2, pxRange: float32): ImageId =
  let id = pathImageId(path, size)
  if hasImage(id):
    return id

  let width = max(1, size.x.round().int)
  let height = max(1, size.y.round().int)
  let mtsdf = generateMtsdfPath(path, width, height, pxRange.float64)
  loadImage(id, mtsdf.image)
  id

proc shapePathData(
    shape: LottieShape, frame: float32
): tuple[path: Path, center: Vec2, size: Vec2, valid: bool] =
  let center =
    vec2FromSeq(valueAtOr(shape.p, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  let size = vec2FromSeq(valueAtOr(shape.s, frame, @[0.0'f32, 0.0'f32]), vec2(0.0, 0.0))
  let roundness = valueAtOr(shape.r, frame, 0.0'f32)

  case shape.ty
  of lstEllipse:
    if size.x <= 0.0'f32 or size.y <= 0.0'f32:
      return (newPath(), center, size, false)
    let path = newPath()
    path.ellipse(
      vec2(size.x / 2.0'f32, size.y / 2.0'f32), size.x / 2.0'f32, size.y / 2.0'f32
    )
    result = (path, center, size, true)
  of lstRect:
    if size.x <= 0.0'f32 or size.y <= 0.0'f32:
      return (newPath(), center, size, false)
    let path = newPath()
    if roundness > 0.0'f32:
      path.roundedRect(
        0.0, 0.0, size.x, size.y, roundness, roundness, roundness, roundness
      )
    else:
      path.rect(0.0, 0.0, size.x, size.y)
    result = (path, center, size, true)
  of lstStar:
    let points = max(3, valueAtOr(shape.points, frame, 0.0'f32).round().int)
    let outerRadius = valueAtOr(shape.outerRadius, frame, 0.0'f32)
    let innerRadius = valueAtOr(shape.innerRadius, frame, 0.0'f32)
    let rotation = valueAtOr(shape.r, frame, 0.0'f32) * (PI / 180.0'f32)
    let starType = shape.starType.get(1.0'f32)
    let isPolygon = starType >= 2.0'f32 or innerRadius <= 0.0'f32
    if points <= 2 or outerRadius <= 0.0'f32:
      return (newPath(), center, vec2(0.0, 0.0), false)
    let path = newPath()
    let baseSize = vec2(outerRadius * 2.0'f32, outerRadius * 2.0'f32)
    let localCenter = vec2(outerRadius, outerRadius)
    if isPolygon:
      for i in 0 ..< points:
        let angle = rotation + (i.float32 * 2.0'f32 * PI / points.float32)
        let pt = vec2(
          localCenter.x + sin(angle) * outerRadius,
          localCenter.y - cos(angle) * outerRadius,
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
        let pt =
          vec2(localCenter.x + sin(angle) * radius, localCenter.y - cos(angle) * radius)
        if i == 0:
          path.moveTo(pt)
        else:
          path.lineTo(pt)
      path.closePath()
    result = (path, center, baseSize, true)
  of lstPath:
    let pathData = valueAtOr(shape.path, frame, default(LottiePath))
    var path = pathFromLottiePath(pathData)
    if pathData.v.len == 0:
      return (newPath(), center, vec2(0.0, 0.0), false)
    let bounds = computeBounds(path)
    let size = vec2(bounds.w, bounds.h)
    let center = vec2(bounds.x + bounds.w / 2.0'f32, bounds.y + bounds.h / 2.0'f32)
    path.transform(translate(vec2(-bounds.x, -bounds.y)))
    result = (path, center, size, true)
  else:
    result = (newPath(), center, size, false)

proc renderShapeGroup(
    list: var RenderList,
    parentIdx: FigIdx,
    layerTransform: LottieResolvedTransform,
    group: LottieShape,
    frame: float32,
    maxSdfSize: float32,
    pxRange: float32,
    sdThreshold: float32,
) =
  var fillOpt: Option[LottieShape]
  var transformOpt: Option[LottieShape]
  var shapes: seq[LottieShape]

  for item in group.it:
    case item.ty
    of lstEllipse, lstRect, lstStar, lstPath:
      shapes.add item
    of lstFill:
      fillOpt = some(item)
    of lstTransform:
      transformOpt = some(item)
    else:
      discard

  if fillOpt.isNone:
    return

  let fill = fillOpt.get
  let fillOpacity = valueAtOr(fill.o, frame, 100.0'f32) / 100.0'f32
  let fillColor = colorFromSeq(valueAtOr(fill.c, frame, @[]), fillOpacity)

  var groupTransform = LottieResolvedTransform(
    anchor: vec2(0.0, 0.0),
    position: vec2(0.0, 0.0),
    scale: vec2(100.0, 100.0),
    rotation: 0.0,
    opacity: 100.0,
  )
  if transformOpt.isSome:
    groupTransform = resolvedTransformFromShape(transformOpt.get, frame)

  for shape in shapes:
    let shapeData = shapePathData(shape, frame)
    if not shapeData.valid:
      continue

    var tcenter = shapeData.center
    var tsize = shapeData.size
    var topacity = 1.0'f32

    block applyGroup:
      let applied = applyTransform(tcenter, tsize, groupTransform)
      tcenter = applied.center
      tsize = applied.size
      topacity = topacity * applied.opacity

    block applyLayer:
      let applied = applyTransform(tcenter, tsize, layerTransform)
      tcenter = applied.center
      tsize = applied.size
      topacity = topacity * applied.opacity

    let baseMax = max(shapeData.size.x, shapeData.size.y)
    let renderScale =
      if baseMax > 0.0'f32:
        min(1.0'f32, maxSdfSize / baseMax)
      else:
        1.0'f32
    let imageSize = vec2(
      max(1.0'f32, shapeData.size.x * renderScale),
      max(1.0'f32, shapeData.size.y * renderScale),
    )
    let imagePxRange = max(1.0'f32, pxRange * renderScale)
    let imageId =
      if shape.ty == lstEllipse:
        ensureEllipseMtsdf(imageSize, imagePxRange)
      else:
        ensurePathMtsdf(shapeData.path, imageSize, imagePxRange)
    let color = color(fillColor.r, fillColor.g, fillColor.b, fillColor.a * topacity)
    let box = rect(
      tcenter.x - tsize.x / 2.0'f32, tcenter.y - tsize.y / 2.0'f32, tsize.x, tsize.y
    )

    list.addChild(
      parentIdx,
      Fig(
        kind: nkMtsdfImage,
        childCount: 0,
        zlevel: 0.ZLevel,
        screenBox: box,
        fill: color,
        mtsdfImage: MsdfImageStyle(
          color: color, id: imageId, pxRange: imagePxRange, sdThreshold: sdThreshold
        ),
      ),
    )

proc initLottieMtsdfRenderer*(
    animation: LottieAnimation,
    pxRange: float32 = 4.0'f32,
    sdThreshold: float32 = 0.5'f32,
    maxSdfSize: float32 = 64.0'f32,
): LottieMtsdfRenderer =
  LottieMtsdfRenderer(
    animation: animation,
    pxRange: pxRange,
    sdThreshold: sdThreshold,
    maxSdfSize: maxSdfSize,
  )

proc renderLottieFrame*(renderer: var LottieMtsdfRenderer, frame: float32): Renders =
  var list = RenderList()
  let rootIdx = list.addRoot(
    Fig(
      kind: nkFrame,
      childCount: 0,
      zlevel: 0.ZLevel,
      screenBox:
        rect(0.0, 0.0, renderer.animation.w.float32, renderer.animation.h.float32),
      fill: color(0.0, 0.0, 0.0, 0.0),
    )
  )

  for layer in renderer.animation.layers:
    if layer.ty != 4:
      continue
    if frame < layer.ip or frame >= layer.op:
      continue

    let layerTransform = resolvedTransform(layer.ks, frame)
    for shape in layer.shapes:
      if shape.ty == lstGroup:
        renderShapeGroup(
          list, rootIdx, layerTransform, shape, frame, renderer.maxSdfSize,
          renderer.pxRange, renderer.sdThreshold,
        )

  result = Renders(layers: initOrderedTable[ZLevel, RenderList]())
  result.layers[0.ZLevel] = list
