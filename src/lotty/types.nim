import std/options

import pkg/jsony

type
  LottieShapeType* = enum
    lstUnknown
    lstGroup
    lstEllipse
    lstRect
    lstStar
    lstPath
    lstFill
    lstTransform

  LottieAnimKind* = enum
    lakStatic = 0
    lakAnimated = 1

  LottieBezier* = object
    x*: seq[float32]
    y*: seq[float32]

  LottiePath* = object
    i*: seq[seq[float32]]
    o*: seq[seq[float32]]
    v*: seq[seq[float32]]
    c*: bool

  LottieKeyframe*[T] = object
    t*: float32
    s*: T
    e*: Option[T]
    i*: Option[LottieBezier]
    o*: Option[LottieBezier]
    h*: Option[int]

  LottieProperty*[T] = object
    case a*: LottieAnimKind
    of lakAnimated:
      kFrames*: seq[LottieKeyframe[T]]
    else:
      kValue*: T

  LottieTransform* = object
    a*: Option[LottieProperty[seq[float32]]]
    p*: Option[LottieProperty[seq[float32]]]
    s*: Option[LottieProperty[seq[float32]]]
    r*: Option[LottieProperty[float32]]
    o*: Option[LottieProperty[float32]]
    sk*: Option[LottieProperty[float32]]
    sa*: Option[LottieProperty[float32]]

  LottieShape* = object
    nm*: string
    p*: Option[LottieProperty[seq[float32]]]
    s*: Option[LottieProperty[seq[float32]]]
    c*: Option[LottieProperty[seq[float32]]]
    o*: Option[LottieProperty[float32]]
    np*: Option[float32]
    points*: Option[LottieProperty[float32]]
    innerRadius*: Option[LottieProperty[float32]]
    outerRadius*: Option[LottieProperty[float32]]
    innerRoundness*: Option[LottieProperty[float32]]
    outerRoundness*: Option[LottieProperty[float32]]
    starType*: Option[float32]
    path*: Option[LottieProperty[LottiePath]]
    it*: seq[LottieShape]
    a*: Option[LottieProperty[seq[float32]]]
    sk*: Option[LottieProperty[float32]]
    sa*: Option[LottieProperty[float32]]
    case ty*: LottieShapeType
    of lstFill:
      fillRule*: Option[int]
    else:
      r*: Option[LottieProperty[float32]]

  LottieLayer* = object
    ty*: int
    nm*: string
    ind*: int
    ip*: float32
    op*: float32
    st*: float32
    ks*: LottieTransform
    shapes*: seq[LottieShape]

  LottieAnimation* = object
    nm*: string
    v*: string
    ver*: int
    fr*: float32
    ip*: float32
    op*: float32
    w*: int
    h*: int
    layers*: seq[LottieLayer]

proc renameHook*[T](v: var LottieProperty[T], key: var string) =
  if key == "k":
    if v.a == lakAnimated:
      key = "kFrames"
    else:
      key = "kValue"

proc parseFloatOrSeq1(raw: string): float32 =
  try:
    result = jsony.fromJson(raw, float32)
  except:
    let values = jsony.fromJson(raw, seq[float32])
    if values.len > 0:
      result = values[0]

proc parseSeqFloatOrSingle(raw: string): seq[float32] =
  try:
    let value = jsony.fromJson(raw, float32)
    result = @[value]
  except:
    result = jsony.fromJson(raw, seq[float32])

proc parseHook*(s: string, i: var int, v: var seq[float32]) =
  var raw: RawJson
  parseHook(s, i, raw)
  v = parseSeqFloatOrSingle(string(raw))

proc parseHook*(s: string, i: var int, v: var LottieKeyframe[float32]) =
  type LottieKeyframeWire = object
    t*: float32
    s*: RawJson
    e*: Option[RawJson]
    i*: Option[LottieBezier]
    o*: Option[LottieBezier]
    h*: Option[int]

  var wire: LottieKeyframeWire
  parseHook(s, i, wire)
  v = default(LottieKeyframe[float32])
  v.t = wire.t
  v.s = parseFloatOrSeq1(string(wire.s))
  if wire.e.isSome:
    v.e = some(parseFloatOrSeq1(string(wire.e.get)))
  v.i = wire.i
  v.o = wire.o
  v.h = wire.h

proc parseHook*(s: string, i: var int, v: var LottieBezier) =
  type LottieBezierWire = object
    x*: RawJson
    y*: RawJson

  var wire: LottieBezierWire
  parseHook(s, i, wire)
  v = default(LottieBezier)
  v.x = parseSeqFloatOrSingle(string(wire.x))
  v.y = parseSeqFloatOrSingle(string(wire.y))

proc renameHook*(v: var LottieShape, key: var string) =
  if key == "r" and v.ty == lstFill:
    key = "fillRule"
  elif key == "pt":
    key = "points"
  elif key == "ir":
    key = "innerRadius"
  elif key == "or":
    key = "outerRadius"
  elif key == "is":
    key = "innerRoundness"
  elif key == "os":
    key = "outerRoundness"
  elif key == "sy":
    key = "starType"
  elif key == "ks":
    key = "path"

proc parseHook*(s: string, i: var int, v: var LottieShapeType) =
  var raw: string
  parseHook(s, i, raw)
  case raw
  of "gr":
    v = lstGroup
  of "el":
    v = lstEllipse
  of "rc":
    v = lstRect
  of "sr":
    v = lstStar
  of "sh":
    v = lstPath
  of "fl":
    v = lstFill
  of "tr":
    v = lstTransform
  else:
    v = lstUnknown
