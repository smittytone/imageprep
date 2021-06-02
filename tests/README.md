# imageprep Tests #

The script `imagepreptest.zsh` performs a sequence of tests on an *imageprep* binary. It uses the image files in the `source` directory.

### Usage ###

1. `cd {path/to/imageprep/tests}`
1. `./imagepreptest.zsh {path/to/imageprep/binary}`

### Outcome ###

If any of tests fail, please [report this as a gitHub issue](https://github.com/smittytone/imageprep/issues), indicating which test failed and providing any information you have about any changes you made to the test script or the imageprep source.

If all the tests pass — the expected outcome — remember to delete the test artifacts from the `tests` directory before re-running the tests.
