import unittest
import os
import times
import strutils
import random
randomize()

import changer

# clean up from the last test run
const TMPROOT = "_unittest_tmp"
if dirExists(TMPROOT):
  echo "Deleting old test tmp dir: ", TMPROOT
  removeDir(TMPROOT)

template tmpdir(body: untyped): untyped =
  let
    originalDir = getCurrentDir().absolutePath()
    dirname = TMPROOT / now().format("YYYYMMddHHmmss") & $rand(100000)
  createDir(dirname)
  try:
    setCurrentDir(dirname)
    body
  finally:
    setCurrentDir(originalDir)

test "replacements":
  tmpdir:
    runChanger "init"
    writeFile("changes"/"config.toml", """
[[replacement]]
pattern = '#(\d+)'
replace = "[#$1](link:$1)"
""")
    writeFile("changes"/"fix-something.md", "Hi #45!")
    runChanger "bump"
    let guts = readFile("CHANGELOG.md")
    check "Hi [#45](link:45)!" in guts


suite "initial version 0.1.0":
  test "fix":
    tmpdir:
      runChanger "init"
      writeFile("changes"/"fix-something.md", "Hi something")
      runChanger "bump"
      let guts = readFile("CHANGELOG.md")
      check "0.1.0" in guts
  
  test "new":
    tmpdir:
      runChanger "init"
      writeFile("changes"/"new-something.md", "Hi something")
      runChanger "bump"
      let guts = readFile("CHANGELOG.md")
      check "0.1.0" in guts

  test "other":
    tmpdir:
      runChanger "init"
      writeFile("changes"/"other-something.md", "Hi something")
      runChanger "bump"
      let guts = readFile("CHANGELOG.md")
      check "0.1.0" in guts
