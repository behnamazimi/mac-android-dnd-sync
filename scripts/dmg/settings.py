# dmgbuild settings for the Mac GitHub Release image.
# Invoked as: dmgbuild -s settings.py -D app=/path/to/DNDSync.app "DND Sync" out.dmg
#
# builtin-arrow is dmgbuild's stock background (app on the left, Applications
# on the right, arrow between). Window size is the compact installer shape,
# not Finder's default huge folder window. The .app keeps its original
# bundle name (DNDSync.app), same as the export.

import os

application = defines["app"]  # noqa: F821
appname = os.path.basename(application)

files = [application]
symlinks = {"Applications": "/Applications"}

format = "UDZO"
default_view = "icon-view"
background = "builtin-arrow"

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0

# y is from the bottom of the screen. Finder keeps the window on-display.
window_rect = ((200, 160), (640, 280))
icon_size = 128
text_size = 14
icon_locations = {
    appname: (140, 120),
    "Applications": (500, 120),
}
