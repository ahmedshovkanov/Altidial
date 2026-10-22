#!/usr/bin/env python3
"""Resizes the generated icon master into every size the asset catalog asks for,
and copies the launch logo into the launch image set.

The App Store rejects an app icon with an alpha channel, and Flutter always
writes one, so the master is flattened first by a lossless-enough round trip
through JPEG at maximum quality.

Run from the repository root, after
`flutter test tool/brand/generate_brand_assets.dart`. Needs macOS `sips`.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ICONS = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
LAUNCH = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
MASTER = 'build/brand/icon-master-rgba.png'


def sips(*args):
    subprocess.run(['sips', *args], check=True, capture_output=True)


def has_alpha(path):
    out = subprocess.run(
        ['sips', '-g', 'hasAlpha', path], check=True, capture_output=True, text=True
    ).stdout
    return 'hasAlpha: yes' in out


def main():
    if not os.path.exists(MASTER):
        sys.exit(f'missing {MASTER}: run the generator first')

    with tempfile.TemporaryDirectory() as tmp:
        jpeg = os.path.join(tmp, 'master.jpg')
        flat = os.path.join(tmp, 'master-flat.png')
        sips('-s', 'format', 'jpeg', '-s', 'formatOptions', '100', MASTER, '--out', jpeg)
        sips('-s', 'format', 'png', jpeg, '--out', flat)
        if has_alpha(flat):
            sys.exit('could not remove the alpha channel from the icon master')

        with open(f'{ICONS}/Contents.json') as f:
            contents = json.load(f)
        for image in contents['images']:
            side = float(image['size'].split('x')[0]) * int(image['scale'].rstrip('x'))
            pixels = round(side)
            out = os.path.join(ICONS, image['filename'])
            sips('-z', str(pixels), str(pixels), flat, '--out', out)
            if has_alpha(out):
                sys.exit(f'{out} still has an alpha channel')
            print(f'icon   {pixels:>4} px  {out}')

    for scale, name in ((1, 'LaunchImage.png'), (2, 'LaunchImage@2x.png'), (3, 'LaunchImage@3x.png')):
        source = f'build/brand/launch-logo-{scale}x.png'
        if not os.path.exists(source):
            sys.exit(f'missing {source}: run the generator first')
        shutil.copyfile(source, os.path.join(LAUNCH, name))
        print(f'launch {120 * scale:>4} px  {os.path.join(LAUNCH, name)}')


if __name__ == '__main__':
    main()
