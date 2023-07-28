# imageprep 7.0.0 #

*imageprep* is an image preparation utility for macOS. It is essentially a wrapper for *sips*.

## Breaking Change

From 7.0.0, *imageprep* no longer deletes source files by default as they are processed. For this reason, the `-k` and `--keep` switches have been removedand their use will throw an error.

To enforce source-file deletion, please use the new `-x` switch.

## Usage

```
imageprep [--source path] [--destination path] \
          [--action s scale_height scale_width] \
          [--action p pad_height pad_width] \
          [--action c crop_height crop_width] \
          [--cropfrom anchor_point] [--offset y-coord x-coord] \
          [--colour pad_colour] [--resolution dpi_value] \
          [--format format_type] [--keep] [--overwrite] \
          [--info] [--createdirs] \
          [--help] [--version] \
          {/path/to/file} ... {path/to/file}
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
|      | `--offset` | `{x} {y}` | Set an anchor point for crop actions. See [**Anchor Points**](#anchor-points) below |
| `-r` | `--resolution` | `{dpi}` | Set the image dpi, eg. 300 |
| `-f` | `--format` | `{format}` | Set the image format: JPG/JPEG, PNG, GIF, BMP or TIF/TIFF |
| `-j` |  | `{level}` | Specify a compression level (percentage) for JPEG images. Default: 80 |
|      | `--createdirs` |  | Create intermediate directories to the destination, if needed. Default: do not create |
| `-o` | `--overwrite` |  | Overwrite an existing file. Without this, existing files will be kept |
|      | `--info` |  | Output image information in machine-readable form: path, width, height, resolution and alpha state |
| `-x` |  |  | Delete the source file. Without this, the source will be retained |
| `-q` | `--quiet` |  | Silence output messages (errors excepted) |
| `-h` | `--help` |  | Show help information |
|      | `--version` |  | Show version information |

You can add any number of actions: they will be applied in the order they appear at the command line.

### Anchor Points ###

You can specify an anchor point for crop operations. Use the `--cropfrom` switch and a value to indicate the anchor point: text markers, eg. `tr` for top-right, `bl` for bottom-left or `cr` for centre-right, etc., or a numerical value:

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

You can specify crop anchors as x and y co-ordinates: this is the co-ordinate of the top left point of the retained area. For example, with a 1920 x 1080 image, to crop out all but a 500 by 400 area in the top left of the image, you would specify 500 and 400 as your width and height values, and 10 and 20 as your offset co-ordinates. Offset values cannot be negative, and values beyond the dimensions of the source image will be ignored.

Please note that if you specify a crop anchor point using `--cropfrom`, it will override any offset value you specify.

## JPEG Compression ##

Any output JPEG images are compressed. The default quality setting is 80%. From version 7.0.0, you can specify an alternative value using the `-j` switch followed by a percentage value, eg, `-j 55`.

## Contributions ##

Contributions are welcome, but pull requestss can only be accepted when they target the `develop` branch. PRs targetting `main` will be rejected.

## Release Notes ##

- 7.0.0 *Unreleased*
    - Support the loading of individual files, not just a directory.
    - Deleting source files after processing is no longer the default -- see [Breaking Change](#breaking-change), above.
    - Allow the compression level of JPEG output to be specified by the user.
- 6.3.4 *25 May 2022*
    - Add `man` page.
- 6.3.3 *23 July 2021*
    - Replace async signal unsafe ctrl-c trapper with safe one.
- 6.3.2 *16 June 2021*
    - Correct a regular expression bug.
- 6.3.1 *16 June 2021*
    - Add better, broader fix for `sips` `no zero offsets, please’ issue.
- 6.3.0 *2 June 2021*
    - Add `--offset` flag to set an alternative crop anchor point.
    - Better checking for missing value arguments.
- 6.2.1 *13 January 2021*
    - No code changes — packaging update only.
- 6.2.0 *28 December 2020*
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

*imageprep* is copyright &copy; 2023, Tony Smith.

## Licence ##

*imageprep*’s source code is issued under the [MIT Licence](./LICENSE).
