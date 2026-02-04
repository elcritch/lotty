--nimcache:".nimcache/"
--passc:"-Wno-incompatible-function-pointer-types"

import std/strutils

task test, "run unit test":
  for file in listFiles("tests"):
    if file.endsWith(".nim") and file.startsWith("t"):
      exec "nim c -r " & file
  for file in listFiles("examples"):
    if file.endsWith(".nim") and file.startsWith("t"):
      exec "nim c " & file
