import argparse
import parsetoml
import regex
import std/os
import std/strformat
import std/tables
import std/times

const README = slurp"../README.md"
const DEFAULT_CONFIG = slurp"../default.config.toml"

when defined(testmode):
  var lastout = ""
  var lasterr = ""
  proc lastStdout*: string =
    result = lastout
    lastout = ""
  proc lastStderr*: string =
    result = lasterr
    lasterr = ""

template echoOut(x: string) =
  when defined(testmode):
    lastout &= x & "\n"
  echo x

template echoErr(x: string) =
  when defined(testmode):
    lasterr &= x & "\n"
  stderr.write(x & "\n")

type
  Version = tuple
    major: int
    minor: int
    patch: int
  ChangeType = enum
    Break = "break"
    New = "new"
    Fix = "fix"
    Other = "other"
  ChangeData = tuple
    changes: Table[ChangeType, seq[string]]
    changefiles: seq[string]

proc getMostRecentVersion(changelogfile: string): string =
  ## Read the current CHANGELOG.md for the most recent version
  let firstline = readFile(changelogfile).strip().splitLines()[0]
  if firstline == "":
    return "0.0.0" # no changelog
  else:
    return firstline.split(" ")[1].substr(1)

proc parseVersion(version: string): Version =
  let parts = version.strip(chars={' ','\t','\n','\r','v'}).split(".").mapIt(parseInt(it))
  result = (parts[0], parts[1], parts[2])

proc `$`(version: Version): string =
  result = &"{version.major}.{version.minor}.{version.patch}"

proc incMajor(version: Version): Version =
  (version.major + 1, 0, 0)

proc incMinor(version: Version): Version =
  (version.major, version.minor + 1, 0)

proc incPatch(version: Version): Version =
  (version.major, version.minor, version.patch + 1)

proc normalizeEntry(x: string, changetype: ChangeType): string =
  result = x.strip().strip(trailing = false, chars = {'-',' '})
  case changetype:
  of Fix:
    result = "- **FIX:** " & result
  of Break:
    result = "- **BREAKING CHANGE:** " & result
  of New:
    result = "- **NEW:** " & result
  of Other:
    result = "- " & result

proc updateNimbleFile(newversion: string, dryrun = true) =
  for (kind, path) in walkDir("."):
    if path.endswith(".nimble"):
      var lines = path.readFile().splitLines()
      for i in 0..<lines.len:
        var line = lines[i]
        if line.startsWith("version "):
          let parts = line.split("\"")
          lines[i] = parts[0] & '"' & newversion & '"'
          break
      echoErr "updating " & path
      if not dryrun:
        path.writeFile(lines.join("\l"))

proc updatePackageJsonFile(newversion: string, dryrun = true) =
  let path = "package.json"
  if path.fileExists:
    var lines = path.readFile().splitLines()
    for i in 0..<lines.len:
      var line = lines[i]
      if "\"version\":" in line:
        var parts = line.split("\"")
        parts[3] = newversion
        lines[i] = parts.join("\"")
        break
    echoErr "updating " & path
    if not dryrun:
      path.writeFile(lines.join("\l"))

type Replacement = tuple
  pattern: string
  by: string

proc readReplacements(config: TomlValueRef): seq[Replacement] =
  if config.hasKey("replacement"):
    let r = config["replacement"]
    if not r.isNil and r.kind == Array:
      for elem in r.getElems():
        result.add (elem["pattern"].getStr(), elem["replace"].getStr())

proc slurpChanges(changesdir: string): ChangeData =
  let config = parsetoml.parseFile(changesdir / "config.toml")
  let replacements = config.readReplacements()
  var changes = {
    Other: newSeq[string](),
    Fix: newSeq[string](),
    Break: newSeq[string](),
    New: newSeq[string](),
  }.toTable()
  var filesToDelete = newSeq[string]()
  for (kind, path) in walkDir(changesdir):
    var filename = path.extractFilename
    if filename.endsWith(".md") and "-" in filename:
      let parts = filename.split("-", 1)
      var changetype = parseEnum[ChangeType](parts[0], Other)
      var entry = readFile(path).normalizeEntry(changetype)
      for (pattern, by) in replacements:
        entry = entry.replace(re(pattern), by)
      changes[changetype].add entry
      filesToDelete.add(path)
  return (changes: changes, changefiles: filesToDelete)

proc computeNextVersion(changesdir: string, changelogfile: string): string =
  ## Compute the next version based solely on pending changes
  let changedata = changesdir.slurpChanges()
  let changes = changedata.changes
  var v = changelogfile.getMostRecentVersion().parseVersion()
  if changes[Break].len > 0:
    if v.major == 0:
      v = v.incMinor()
    else:
      v = v.incMajor()
  elif changes[Other].len > 0 or changes[New].len > 0:
    v = v.incMinor()
  elif changes[Fix].len > 0:
    if v == (0,0,0):
      v = v.incMinor()
    else:
      v = v.incPatch()
  else:
    v = v.incMinor()
  result = $v

proc prepareNext(changesdir: string, changelogfile: string, nextVersion = ""): tuple[entry: string, version: string, filesToDelete: seq[string]] =
  ## Prepare the next changelog
  let config = parsetoml.parseFile(changesdir / "config.toml")
  let replacements = config.readReplacements()
  let changedata = changesdir.slurpChanges()
  let changes = changedata.changes

  var nextVersion = nextVersion
  if nextVersion == "":
    nextVersion = computeNextVersion(changesdir, changelogfile)
  
  let date = now().format("yyyy-MM-dd")
  var lines: seq[string]
  lines.add &"# v{nextVersion} - {date}\n"
  for kind in [Break, New, Fix, Other]:
    for item in changes[kind]:
      lines.add(item)
  lines.add("\n")
  return (lines.join("\l"), nextVersion, changedata.changefiles)

proc sanitizeTitle(x: string): string =
  for c in x:
    case c
    of 'a'..'z','A'..'Z','0'..'9':
      result.add c
    of '-','_',' ':
      result.add "-"
    else:
      discard

proc newChangeLogEntry(changesdir: string) =
  if not changesdir.dirExists:
    echoErr "ERROR: Could not find changes dir: " & changesdir
    quit(1)
  var changeType = Other
  echoErr "Change type:" &
  "\l  [F]ix" &
  "\l  [N]ew feature" &
  "\l  [B]reaking change" &
  "\l  [O]ther (default)" &
  "\l  ? "
  var val = stdin.readLine().strip().toLower()
  case val
  of "f": changeType = Fix
  of "n": changeType = New
  of "b": changeType = Break
  else: changeType = Other
  
  echoErr "Describe change (this will show up in the changelog): "
  var description = stdin.readLine()
  var title = description.splitWhitespace(3)[0..^2].join(" ").sanitizeTitle()
  title &= "-" & now().format("yyyyMMdd-HHmmss")
  var filename = case changeType
    of Fix: "fix-"
    of New: "new-"
    of Break: "break-"
    of Other: "other-"
  filename &= title & ".md"
  filename = changesdir / filename
  writeFile(filename, description & "\l")
  echoErr filename

proc bump(changesdir: string, changelogfile: string, nextVersion = "", dryrun = true) =
  let next = prepareNext(changesdir, changelogfile, nextVersion)
  echoOut next.entry
  var guts = readFile(changelogfile)
  guts = next.entry & guts
  if not dryrun:
    writeFile(changelogfile, guts)
  echoErr "updating " & changelogfile & " ..."
  for f in next.filesToDelete:
    if not dryrun:
      removeFile(f)
    echoErr "rm " & f
  let config = parsetoml.parseFile(changesdir / "config.toml")
  if config{"update_nimble"}.getBool(false):
    echoErr "attempting to update .nimble file..."
    updateNimbleFile(next.version, dryrun)
  if config{"update_package_json"}.getBool(false):
    echoErr "attempting to update package.json..."
    updatePackageJsonFile(next.version, dryrun)
  echoErr "ok -> v" & next.version
  if dryrun:
    echoErr "DRY RUN - no files changed"

proc show(changelogfile: string, toshow = 1): string =
  ## Show the top `toshow` entried from the changelog
  var left = toshow
  for line in open(changelogfile).lines():
    if line.startsWith("#"):
      left.dec()
      if left < 0:
        break
    result.add(line & "\n")

proc initDir(changesdir: string, changelogfile: string) =
  if not fileExists(changelogfile):
    echoErr "touch " & changelogfile
    writeFile(changelogfile, "")
  if not dirExists(changesdir):
    echoErr "mkdir " & changesdir
    createDir(changesdir)
  let changereadme = changesdir / "README.md"
  writeFile(changereadme, README)
  echoErr "wrote " & changereadme
  let config = changesdir / "config.toml"
  if not fileExists(config):
    writeFile(config, DEFAULT_CONFIG)
    echoOut "wrote " & config

var parser = newParser("changer"):
  help(README)
  option("-d", "--changes-dir", default = some("changes"))
  option("-f", "--changelog", default = some("CHANGELOG.md"))
  command "init":
    help("Create a new CHANGELOG.md file and changes/ directory")
    run:
      initDir(
        changesdir = opts.parentOpts.changes_dir,
        changelogfile = opts.parentOpts.changelog,
      )
  command "bump":
    help "Combine pending changes into a new release."
    flag("-n", "--dryrun")
    arg("version", default = some(""), help = "Next version to use. If not given, auto-detect.")
    run:
      bump(
        opts.parentOpts.changes_dir,
        opts.parentOpts.changelog,
        opts.version,
        opts.dryrun,
      )
  command "next-version":
    help "Print out the next computed version based on pending changes."
    run:
      echoOut computeNextVersion(
        opts.parentOpts.changes_dir,
        opts.parentOpts.changelog,
      )
  command "current-version":
    help "Print out the current version based on the CHANGELOG file"
    run:
      echoOut getMostRecentVersion(
        opts.parentOpts.changelog,
      )
  command "show":
    help "Show the latest X entries of the CHANGELOG"
    option("-N", "--number", default = some("1"), help = "Number of entries to show")
    run:
      echoOut show(
        opts.parentOpts.changelog,
        opts.number.parseInt(),
      )
  command "add":
    help "Add a new changelog entry."
    run:
      newChangeLogEntry(opts.parentOpts.changes_dir)

when defined(testmode):
  proc runChanger*(args: varargs[string]) =
    parser.run(toSeq(args))
  
  proc runChangerOutput*(args: varargs[string]): string =
    runChanger(args)
    result = lastStdout() & lastStderr()

when isMainModule:
  parser.run()
