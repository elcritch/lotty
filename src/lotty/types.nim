import std/options

import pkg/jsony

type
  LottieAnimKind* = enum
    lakStatic = 0
    lakAnimated = 1

  LottieBezier* = object
    x*: seq[float32]
    y*: seq[float32]

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
    ty*: string
    nm*: string
    p*: Option[LottieProperty[seq[float32]]]
    s*: Option[LottieProperty[seq[float32]]]
    c*: Option[LottieProperty[seq[float32]]]
    o*: Option[LottieProperty[float32]]
    fillRule*: Option[int]
    np*: Option[float32]
    it*: seq[LottieShape]
    a*: Option[LottieProperty[seq[float32]]]
    r*: Option[LottieProperty[float32]]
    sk*: Option[LottieProperty[float32]]
    sa*: Option[LottieProperty[float32]]

  LottieShapeWire = object
    ty*: string
    nm*: string
    p*: Option[LottieProperty[seq[float32]]]
    s*: Option[LottieProperty[seq[float32]]]
    c*: Option[LottieProperty[seq[float32]]]
    o*: Option[LottieProperty[float32]]
    np*: Option[float32]
    it*: Option[seq[LottieShape]]
    a*: Option[LottieProperty[seq[float32]]]
    r*: Option[RawJson]
    sk*: Option[LottieProperty[float32]]
    sa*: Option[LottieProperty[float32]]

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

proc parseHook*(s: string, i: var int, v: var LottieShape) =
  var wire: LottieShapeWire
  parseHook(s, i, wire)
  v = default(LottieShape)
  v.ty = wire.ty
  v.nm = wire.nm
  v.p = wire.p
  v.s = wire.s
  v.c = wire.c
  v.o = wire.o
  v.a = wire.a
  v.sk = wire.sk
  v.sa = wire.sa
  if wire.np.isSome:
    v.np = wire.np
  if wire.it.isSome:
    v.it = wire.it.get
  if wire.r.isSome:
    let raw = string(wire.r.get)
    if v.ty == "fl":
      v.fillRule = some(jsony.fromJson(raw, int))
    else:
      v.r = some(jsony.fromJson(raw, LottieProperty[float32]))
