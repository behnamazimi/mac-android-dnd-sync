# Bundled fonts

The Android app bundles one OFL-licensed typeface from Google Fonts as
`res/font/*.ttf`, so the UI renders identically offline with no runtime
font download:

- **Inter** (variable, `inter_variable.ttf`) — display, titles, body, and
  labels. License: [OFL-Inter.txt](OFL-Inter.txt).

Diagnostics report lines use the platform monospace face and do not
bundle a second typeface.

Inter is licensed under the SIL Open Font License, Version 1.1, which
permits bundling and redistribution as part of this application. Source:
https://github.com/rsms/inter (also on https://github.com/google/fonts
in the `ofl/inter` directory).
