import std/json
import std/os
import std/random
import std/strutils
import std/sequtils
import std/times
import std/unittest
randomize()

import changer

# clean up from the last test run
const TMPROOT = "_unittest_tmp"
if dirExists(TMPROOT):
  echo "Deleting old test tmp dir: ", TMPROOT
  removeDir(TMPROOT)

template cd(dirname: string, body: untyped): untyped =
  block:
    let
      originalDir = getCurrentDir().absolutePath()
    try:
      createDir(dirname)
      setCurrentDir(dirname)
      body
    finally:
      setCurrentDir(originalDir)

template tmpdir(body: untyped): untyped =
  let dirname = TMPROOT / now().format("YYYYMMddHHmmss") & $rand(100000)
  cd dirname:
    body

proc listdir(x: string): seq[string] =
  for x in walkDir(x, relative = true):
    result.add(x.path)

proc listChangeFiles(root: string): seq[string] =
  listdir(root).filterIt("-" in it and it.endsWith(".md"))

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

test "update_nimble":
  tmpdir:
    runChanger "init"
    writeFile("changes"/"config.toml", """
update_nimble = true
    """)
    writeFile("changes"/"fix-something.md", "Hi")
    writeFile("something.nimble", "version       = \"0.0.0\"")
    runChanger "bump"
    let guts = readFile("something.nimble")
    check "0.1.0" in guts

test "update_package_json":
  tmpdir:
    runChanger "init"
    writeFile("changes"/"config.toml", """
update_package_json = true
    """)
    writeFile("changes"/"fix-thing.md", "thing")
    writeFile("package.json", """
{
  "version": "0.0.0"
}
""")
    runChanger "bump"
    let guts = readFile("package.json").parseJson
    check guts["version"].getStr() == "0.1.0"

test "show":
  tmpdir:
    runChanger "init"
    writeFile("changes"/"fix-1.md", "thing1")
    writeFile("changes"/"fix-2.md", "thing2")
    runChanger "bump"
    block:
      let output = runChangerOutput "show"
      check "thing1" in output
      check "thing2" in output
    writeFile("changes"/"fix-3.md", "thing3")
    runChanger "bump"
    block:
      let output = runChangerOutput "show"
      check "thing3" in output
      check "thing1" notin output
      check "thing2" notin output
    block:
      let output = runChangerOutput(["show", "--number", "2"])
      check "thing1" in output
      check "thing2" in output
      check "thing3" in output

suite "initial version 0.1.0":
  test "fix":
    tmpdir:
      runChanger "init"
      runChanger "add", "-t", "fix", "-m", "Hi something"
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

suite "duplicate":

  test "copy":
    tmpdir:
      cd "b":
        runChanger "init"
      cd "c":
        runChanger "init"
      cd "a":
        runChanger "init"
        writeFile("changes"/"config.toml", """
[[duplicate]]
dst = '../../b/changes'

[[duplicate]]
dst = '../../c/changes'
""")
        runChanger "add", "-t", "other", "-m", "Change 1"
      let filename = listChangeFiles("a"/"changes")[0]
      let contents = readFile("a"/"changes"/filename)
      check readFile("b"/"changes"/filename) == contents
      check readFile("c"/"changes"/filename) == contents

      