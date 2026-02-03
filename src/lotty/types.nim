import std/options

import pkg/jsony

type
  LottieShapeType* = enum
    lstUnknown
    lstGroup
    lstEllipse
    lstFill
    lstTransform

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
    nm*: string
    p*: Option[LottieProperty[seq[float32]]]
    s*: Option[LottieProperty[seq[float32]]]
    c*: Option[LottieProperty[seq[float32]]]
    o*: Option[LottieProperty[float32]]
    np*: Option[float32]
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

proc renameHook*(v: var LottieShape, key: var string) =
  if key == "r" and v.ty == lstFill:
    key = "fillRule"

proc parseHook*(s: string, i: var int, v: var LottieShapeType) =
  var raw: string
  parseHook(s, i, raw)
  case raw
  of "gr":
    v = lstGroup
  of "el":
    v = lstEllipse
  of "fl":
    v = lstFill
  of "tr":
    v = lstTransform
  else:
    v = lstUnknown
