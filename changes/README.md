`changer` makes it easy to manage a `CHANGELOG.md` file.

# Installation

```
nimble install https://github.com/iffy/changer
```

# Usage

Start a changelog in a project by running:

  changer init

Every time you want to add something to the changelog, make a new Markdown file in `./changes/` named like this:

  - `fix-NAME.md`
  - `new-NAME.md`
  - `break-NAME.md`
  - `other-NAME.md`

Use the tool to add a log for you:

  changer add

When you're ready to release a new version, preview the new changelog with:

  changer bump -n

Then make the new changelog (and update the version of any `.nimble` file):

  changer bump
