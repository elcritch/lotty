--nimcache:".nimcache/"
--passc:"-Wno-incompatible-function-pointer-types"

import std/strutils

task test, "run unit test":
  for file in listFiles("tests"):
    if file.endsWith(".nim") and file.startsWith("t"):
      exec "nim c -r " & file

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
