# imageprep 6.0.0 #

*imageprep* is an image preparation utility for macOS. It is essentially a wrapper for *sips*.

## Usage

```
imageprep [-s path] [-d path] [-c pad_colour] \
          [-a s scale_height scale_width] \
          [-a p pad_height pad_width] \
          [-a c crop_height crop_width] \
          [-r] [-f] [-k] [-o] [-h]
```

### Options ###

| Switch | Alt.&nbps;Switch&nbps;&nbps;&nbps;&nbps; | Argument(s) | Description |
| :-: | --- | --- | --- |
| `-s` | `--source` | `{path}` | The path to an image or a directory of images. Default: current working directory |
| `-d` | `--destination` | `{path}` | The path to the images. Default: source directory |
| `-a` | `--action` | `{type}{width}{height}` | The crop/pad dimensions. Type is s (scale), c (crop) or p (pad) |
| `-c` | `--colour` | `{colour}` | The padding colour in Hex, eg. A1B2C3. Default: FFFFFF |
| `-r` | `--resolution` | `{dpi}` | Set the image dpi, eg. 300 |
| `-f` | `--format` | `{format}` | Set the image format: JPG/JPEG, PNG or TIF/TIFF |
| `-o` | `--overwrite` |  | Overwrite an existing file. Without this, existing files will be kept |
| `-k` | `--keep` |  | Keep the source file. Without this, the source will be deleted |
| `-q` | `--quiet` |  | Silence output messages (errors excepted) |
| `-h` | `--help` |  | Show help information |

**Note** You can select either crop, pad or scale or all three, but actions will always be performed in this order: crop, pad, then scale.

## Release Notes ##

- 6.0.0 *Unreleased*
    - Initial public release.

**Note** Released as version 6.0.0 for historical reasons: previous versions were released in the form of shell scripts.

## Copyright ##

imageprep is copyright &copy; 2020, Tony Smith.

## Licence ##

imageprep’s source code is issued under the [MIT Licence](./LICENSE).