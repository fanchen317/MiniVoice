#!/usr/bin/env python3
"""Write the install layout without opening Finder or requesting Automation."""
import sys
from pathlib import Path
from ds_store import DSStore
from mac_alias import Alias

volume = Path(sys.argv[1]).resolve()
background = volume / '.background' / 'install.png'
with DSStore.open(str(volume / '.DS_Store'), 'w+') as store:
    store['.']['bwsp'] = {
        'WindowBounds': '{{200, 160}, {640, 360}}',
        'ShowToolbar': False, 'ShowStatusBar': False, 'ShowPathbar': False,
        'ShowSidebar': False, 'ContainerShowSidebar': False,
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1, 'backgroundType': 2,
        'backgroundImageAlias': Alias.for_file(str(background)).to_bytes(),
        'iconSize': 96.0, 'textSize': 14.0, 'gridSpacing': 100.0,
        'arrangeBy': 'none', 'labelOnBottom': True,
        'showItemInfo': False, 'showIconPreview': False,
        'scrollPositionX': 0.0, 'scrollPositionY': 0.0,
    }
    store['.']['vstl'] = ('type', b'icnv')
    store['MiniVoice.app']['Iloc'] = (170, 160)
    store['Applications']['Iloc'] = (470, 160)
# Do not publish an installer if the persisted layout is incomplete.
with DSStore.open(str(volume / '.DS_Store'), 'r') as store:
    assert store['MiniVoice.app']['Iloc'] == (170, 160)
    assert store['Applications']['Iloc'] == (470, 160)
    assert store['.']['icvp']['backgroundType'] == 2
