# dmgbuild settings: writes the Finder window layout directly (no Finder/AppleScript needed).
# Keep coordinates in sync with scripts/make-dmg-background.swift.
app = defines['app']  # noqa: F821  (injected by dmgbuild -D)

format = 'UDZO'
filesystem = 'HFS+'
files = [app, 'Config/dmg/Read Me First.txt']
symlinks = {'Applications': '/Applications'}
background = 'Config/dmg/background.png'

window_rect = ((200, 120), (726, 720))
default_view = 'icon-view'
show_toolbar = False
show_status_bar = False
show_sidebar = False
icon_size = 128
text_size = 13
arrange_by = None
icon_locations = {
    'Second Display.app': (198, 195),
    'Applications': (529, 195),
    'Read Me First.txt': (363, 435),
}
