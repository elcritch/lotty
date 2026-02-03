import pkg/pixie

import ./types

proc vec2FromSeq(vals: seq[float32], fallback: Vec2): Vec2 =
  if vals.len >= 2:
    vec2(vals[0], vals[1])
  elif vals.len == 1:
    vec2(vals[0], vals[0])
  else:
    fallback

proc pathFromLottiePath*(pathData: LottiePath, flipY: bool = false): Path =
  var path = newPath()
  if pathData.v.len == 0:
    return path

  let firstRaw = vec2FromSeq(pathData.v[0], vec2(0.0, 0.0))
  let first =
    if flipY:
      vec2(firstRaw.x, -firstRaw.y)
    else:
      firstRaw
  path.moveTo(first)

  let lastIndex = pathData.v.len - 1
  for i in 0 ..< lastIndex:
    let v0Raw = vec2FromSeq(pathData.v[i], vec2(0.0, 0.0))
    let v1Raw = vec2FromSeq(pathData.v[i + 1], vec2(0.0, 0.0))
    let o0Raw =
      if i < pathData.o.len:
        vec2FromSeq(pathData.o[i], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)
    let i1Raw =
      if i + 1 < pathData.i.len:
        vec2FromSeq(pathData.i[i + 1], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)

    let v0 =
      if flipY:
        vec2(v0Raw.x, -v0Raw.y)
      else:
        v0Raw
    let v1 =
      if flipY:
        vec2(v1Raw.x, -v1Raw.y)
      else:
        v1Raw
    let o0 =
      if flipY:
        vec2(o0Raw.x, -o0Raw.y)
      else:
        o0Raw
    let i1 =
      if flipY:
        vec2(i1Raw.x, -i1Raw.y)
      else:
        i1Raw

    path.bezierCurveTo(v0 + o0, v1 + i1, v1)

  if pathData.c:
    let vLastRaw = vec2FromSeq(pathData.v[lastIndex], vec2(0.0, 0.0))
    let vFirstRaw = vec2FromSeq(pathData.v[0], vec2(0.0, 0.0))
    let oLastRaw =
      if lastIndex < pathData.o.len:
        vec2FromSeq(pathData.o[lastIndex], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)
    let iFirstRaw =
      if 0 < pathData.i.len:
        vec2FromSeq(pathData.i[0], vec2(0.0, 0.0))
      else:
        vec2(0.0, 0.0)

    let vLast =
      if flipY:
        vec2(vLastRaw.x, -vLastRaw.y)
      else:
        vLastRaw
    let vFirst =
      if flipY:
        vec2(vFirstRaw.x, -vFirstRaw.y)
      else:
        vFirstRaw
    let oLast =
      if flipY:
        vec2(oLastRaw.x, -oLastRaw.y)
      else:
        oLastRaw
    let iFirst =
      if flipY:
        vec2(iFirstRaw.x, -iFirstRaw.y)
      else:
        iFirstRaw

    path.bezierCurveTo(vLast + oLast, vFirst + iFirst, vFirst)
    path.closePath()

  path
