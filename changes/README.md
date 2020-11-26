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

