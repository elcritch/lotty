import pkg/pixie

import ./types

proc vec2FromSeq(vals: seq[float32], fallback: Vec2): Vec2 =
  if vals.len >= 2:
    vec2(vals[0], vals[1])
  elif vals.len == 1:
    vec2(vals[0], vals[0])
  else:
    fallback

proc pathFromLottiePath*(pathData: LottiePath): Path =
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
