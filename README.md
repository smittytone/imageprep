# imageprep 6.2.0 #

*imageprep* is an image preparation utility for macOS. It is essentially a wrapper for *sips*.

## Usage

```
imageprep [--source path] [--destination path] \
          [--action s scale_height scale_width] \
          [--action p pad_height pad_width] \
          [--action c crop_height crop_width] \
          [--cropfrom anchor_point] [--colour pad_colour] \
          [--resolution dpi_value] [--format format_type] \
          [--keep] [--overwrite] [--info] [--createdirs] \
          [--help] [--version]
```

For more detailed guidance on using *imageprep*, please [see this page](https://smittytone.net/imageprep/).

### Options ###

| Switch | Alternative&nbsp;Switch | Argument(s) | Description |
| :-: | --- | --- | --- |
| `-s` | `--source` | `{path}` | The path to an image or a directory of images. Default: current working directory |
| `-d` | `--destination` | `{path}` | The path to the images. Default: source directory |
| `-a` | `--action` | `{type}`&nbsp;`{width}`&nbsp;`{height}` | The crop/pad dimensions. Type is s (scale), c (crop) or p (pad), eg. `-a s 200 200` |
| `-c` | `--colour` | `{colour}` | The padding colour in Hex, eg. `A1B2C3`. Numbers may be prefixed `#`, `$` or `0x`, or habve no prefix. Default: `FFFFFF` |
|      | `--cropfrom` | `{anchor point}` | Set an anchor point for crop actions. See [**Anchor Points**](#anchor-points) below |
| `-r` | `--resolution` | `{dpi}` | Set the image dpi, eg. 300 |
| `-f` | `--format` | `{format}` | Set the image format: JPG/JPEG, PNG, GIF, BMP or TIF/TIFF |
|      | `--createdirs` |  | Create intermediate directories to the destination, if needed. Default: do not create |
| `-o` | `--overwrite` |  | Overwrite an existing file. Without this, existing files will be kept |
|      | `--info` |  | Output image information in machine-readable form: path, width, height, resolution and alpha state |
| `-k` | `--keep` |  | Keep the source file. Without this, the source will be deleted |
| `-q` | `--quiet` |  | Silence output messages (errors excepted) |
| `-h` | `--help` |  | Show help information |
|      | `--version` |  | Show version information |

You can add any number of actions: they will be applied in the order they appear at the command line.

### Anchor Points ###

From version 6.2.0, you can specify an anchor point for crop operations. Use the `--cropfrom` switch and a value to indicate the anchor point: text markers, eg. `tr` for top-right, `bl` for bottom-left or `cr` for centre-right, etc., or a numerical value:

| &nbsp; | Left | Centre | Right |
| :-: | :-: | :-: | :-: |
| **Top** | `TL` | `TC` | `TR` |
| **Centre** | `CL` | N/A | `CR` |
| **Bottom** | `BL` | `BC` | `BR` |

| &nbsp; | Left | Centre | Right |
| :-: | :-: | :-: | :-: |
| **Top** | `0` | `1` | `2` |
| **Centre** | `3` | N/A | `5` |
| **Bottom** | `6` | `7` | `8` |

## Release Notes ##

- 6.2.0 *Unreleased*
    - Add `--cropfrom` flag to select a crop anchor point.
    - Add `--info` argument.
    - Add the ability to crop/scale/pad to the width or height of the source image.
    - Add the ability to crop/scale/pad to a specified width or height using the aspect ratio of the source image.
    - Refactor code.
- 6.1.0 *21 December 2020*
    - Add optional destination intermediate directory creation.
    - Ignore sub-directories in the source directory for file-safety reasons.
    - Colourise output for greater visibility.
    - Sort source file list before processing.
    - Write all messages to user via `stderr` ([click here to see why](https://clig.dev/#the-basics)).
    - Correctly trap `SIGINT`.
    - Correctly keep source file when no target file is named.
    - Add examples to help text.
    - Add test suite.
- 6.0.0 *2 December 2020*
    - Initial public release.

**Note** *imageprep* was initially released as version 6.0.0 for historical reasons: previous versions were released in the form of shell scripts.

## Copyright ##

*imageprep* is copyright &copy; 2020, Tony Smith.

## Licence ##

*imageprep*’s source code is issued under the [MIT Licence](./LICENSE).