# v0.9.1 - 2024-04-19

- **FIX:** Use version of regex that supports Nim 1.2.x

# v0.9.0 - 2024-03-09

- **NEW:** You can now specify directories to copy changelog entries to with [[duplicate]]
- **NEW:** You can specify change parameters to `add` command to make it fully non-interactive

# v0.8.0 - 2023-07-11

- **NEW:** Added the `show` command to make it easier to show the latest N entries of the changelog

# v0.7.0 - 2021-12-29

- **NEW:** Added `current-version` command.

# v0.6.2 - 2021-07-15

- **FIX:** Changed default config.toml to correct order for global configuration options

# v0.6.1 - 2021-07-15

- **FIX:** Changer no longer fails if the new `update_package_json` or `update_nimble` config variables are absent.

# v0.6.0 - 2021-07-14


# v0.5.0 - 2021-07-14

- **NEW:** Added 'changer next-version' to show what it will choose as the next version.

# v0.4.2 - 2021-03-17

- **FIX:** When creating the CHANGELOG for the first time, always choose v0.1.0

# v0.4.1 - 2020-12-09

- **FIX:** `changer add` fails immediately if there's no changes/ directory (instead of failing at the end).

# v0.4.0 - 2020-12-09

- **NEW:** Changer won't automatically bump from 0.x.x to 1.x.x anymore

# v0.3.0 - 2020-12-01

- **NEW:** You can now perform string replacements on each snippet via a config file. This allows you to do things like automatically add links to your issue tracker.

# v0.2.0 - 2020-11-28

- **NEW:** Added CI tests.
- **NEW:** `changer add` no longer asks for a separate title and description.

# v0.1.1 - 2020-11-25

- **FIX:** Updated the docs for the bump command.

# v0.1.0 - 2020-11-25

- Initial release

