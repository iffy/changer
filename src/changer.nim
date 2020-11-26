import argparse
import os
import osproc
import times
import tables
import strformat
import rdstdin

const README = """
Every time you want to add something to the changelog, make a new Markdown
file in changes/ named like this:

  - `fix-NAME.md`
  - `new-NAME.md`
  - `break-NAME.md`
  - `other-NAME.md`

When you're ready to release a new version, preview the new changelog with:

  changer cat

Then make the new changelog with:

  changer bump

"""

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

proc getMostRecentVersion(changelogfile: string): string =
  ## Read the current CHANGELOG.md for the most recent version
  let firstline = readFile(changelogfile).strip().splitLines()[0]
  if firstline == "":
    return "0.1.0" # no changelog
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
      echo "updating ", path
      if not dryrun:
        path.writeFile(lines.join("\l"))
      

proc prepareNext(changesdir: string, changelogfile: string, nextVersion = ""): tuple[entry: string, version: string, filesToDelete: seq[string]] =
  ## Prepare the next changelog
  var changes = {
    Other: newSeq[string](),
    Fix: newSeq[string](),
    Break: newSeq[string](),
    New: newSeq[string](),
  }.toTable()
  var filesToDelete: seq[string]
  for (kind, path) in walkDir(changesdir):
    var filename = path.extractFilename
    if filename.endsWith(".md") and "-" in filename:
      let parts = filename.split("-", 1)
      var changetype = parseEnum[ChangeType](parts[0], Other)
      changes[changetype].add readFile(path).normalizeEntry(changetype)
      filesToDelete.add(path)

  var nextVersion = nextVersion
  if nextVersion == "":
    nextVersion = changelogfile.getMostRecentVersion()
    var v = nextVersion.parseVersion()
    if changes[Break].len > 0:
      v = v.incMajor()
    elif changes[Other].len > 0 or changes[New].len > 0:
      v = v.incMinor()
    elif changes[Fix].len > 0:
      v = v.incPatch()
    else:
      v = v.incMinor()
    nextVersion = $v
  
  let date = now().format("yyyy-MM-dd")
  var lines: seq[string]
  lines.add &"# v{nextVersion} - {date}\n"
  for kind in [Break, New, Fix, Other]:
    for item in changes[kind]:
      lines.add(item)
  lines.add("\n")
  return (lines.join("\l"), nextVersion, filesToDelete)

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
  var changeType = Other
  var val = readLineFromStdin("Change type:" &
  "\r\n  [F]ix" &
  "\r\n  [N]ew feature" &
  "\r\n  [B]reaking change" &
  "\r\n  [O]ther (default)" &
  "\r\n  ? ").strip().toLower()
  case val
  of "f": changeType = Fix
  of "n": changeType = New
  of "b": changeType = Break
  else: changeType = Other
  
  var title = readLineFromStdin("Short, unique keyword(s)? [Default current timestamp] ").sanitizeTitle()
  if title == "":
    title = now().format("yyyyMMdd-HHmmss")
  var filename = case changeType
    of Fix: "fix-"
    of New: "new-"
    of Break: "break-"
    of Other: "other-"
  filename &= title & ".md"
  filename = changesdir / filename
  writeFile(filename, "- \l")
  var editor = getEnv("EDITOR")
  if editor != "":
    discard execCmd(editor & " " & filename) # TODO this probably isn't safe
  echo filename

proc bump(changesdir: string, changelogfile: string, nextVersion = "", dryrun = true) =
  let next = prepareNext(changesdir, changelogfile, nextVersion)
  echo next.entry
  var guts = readFile(changelogfile)
  guts = next.entry & guts
  if not dryrun:
    writeFile(changelogfile, guts)
  echo "updating ", changelogfile, " ..."
  for f in next.filesToDelete:
    if not dryrun:
      removeFile(f)
    echo "rm ", f
  updateNimbleFile(next.version, dryrun)
  echo "ok -> v", next.version
  if dryrun:
    echo "DRY RUN - no files changed"

var p = newParser("changer"):
  help(README)
  option("-d", "--changes-dir", default = some("changes"))
  option("-f", "--changelog", default = some("CHANGELOG.md"))
  command "init":
    help("Create a new CHANGELOG.md file and changes/ directory")
    run:
      if not fileExists(opts.parentOpts.changelog):
        writeFile(opts.parentOpts.changelog, "")
      if not dirExists(opts.parentOpts.changes_dir):
        createDir(opts.parentOpts.changes_dir)
      let changereadme = opts.parentOpts.changes_dir / "README.md"
      writeFile(changereadme, README)

  command "bump":
    flag("-n", "--dryrun")
    arg("version", default = some(""), help = "Next version to use. If not given, auto-detect.")
    run:
      bump(
        opts.parentOpts.changes_dir,
        opts.parentOpts.changelog,
        opts.version,
        opts.dryrun,
      )
  command "add":
    help "Add a new changelog entry."
    run:
      newChangeLogEntry(opts.parentOpts.changes_dir)
when isMainModule:
  p.run()
