# Package

version       = "0.9.1"
author        = "Matt Haggard"
description   = "Makes doing changelogs easier"
license       = "MIT"
srcDir        = "src"
bin           = @["changer"]


# Dependencies

requires "nim >= 1.2.8"
requires "argparse >= 0.10.1"
requires "regex >= 0.15.0 & < 0.25.0"
requires "parsetoml >= 0.5.0"
