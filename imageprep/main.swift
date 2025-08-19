/*
    imageprep
    main.swift

    Copyright © 2025 Tony Smith. All rights reserved.

    MIT License
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

import Foundation
import Cocoa


// MARK: Constants

let SUPPORTED_TYPES: [String]   = ["png", "jpeg", "tiff", "pict", "bmp", "gif", "jpg", "tif"]
let DEDUPE_INDEX: Int           = 6
let EMPTY_HEX_BYTES: String     = "000000"
// FROM 6.2.0
let BASE_DPI: CGFloat           = 72.0
let USE_IMAGE: Int              = -1
let SCALE_TO_WIDTH: Int         = -2
let SCALE_TO_HEIGHT: Int        = -3
let ACTION_TYPES: [String]      = ["c", "s", "p"]


// MARK: Global Variables

// File management values
let fm: FileManager             = FileManager.default
var sourcePath: String          = FileManager.default.currentDirectoryPath
var sourceFile: String          = ""
var sourceIsdirectory: ObjCBool = false
var destPath: String            = ""
var destFile: String            = ""
var destIsdirectory: ObjCBool   = false
var doOverwrite: Bool           = false
// FROM 6.1.0
var doMakeSubDirectories: Bool  = false
var isPiped: Bool               = false

// Image attributes and action flags
var padColour: String           = "FFFFFF"
var cropHeight: Int             = 2182
var cropWidth: Int              = 1668
var padHeight: Int              = 2192
var padWidth: Int               = 1668
var scaleHeight                 = padHeight
var scaleWidth                  = padWidth
var dpi: Float                  = 150.0
var newFormatForSips: String    = ""
var formatExtension: String     = "png"
var doReformat: Bool            = false
var doChangeResolution: Bool    = false
var didChangeResolution: Bool   = false
var doShowMessages: Bool        = true
var doDeleteSource: Bool        = false         // Default to false in 7.0.0
var actions: NSMutableArray     = NSMutableArray.init()
// FROM 6.2.0
var justInfo: Bool              = false
var cropFix: Int                = 4
// FROM 6.3.0
var cropLeft: Int               = -1
var cropDown: Int               = -1
// FROM 7.0.0
var sourceFiles: [String]       = []
var jpegCompression: Double     = 80.0

// CLI argument management
var argValue: Int               = 0
var argCount: Int               = 0
var actionType: String          = "c"
var prevArg: String             = ""
var fileCount: Int              = 0


// MARK: Runtime Start

// FROM 6.3.2
// Make sure the signal does not terminate the application
Stdio.enableCtrlHandler("impageprep interrupted -- cancelling")

// FROM 6.1.0
// No arguments? Show Help
var args: [String] = CommandLine.arguments
if args.count == 1 {
    showHelp()
    Stdio.disableCtrlHandler()
    exit(EXIT_SUCCESS)
}

// FROM 6.3.0
// Use a regex so negative values are not mistaken for switches
let cmdRegExp: NSRegularExpression = try! NSRegularExpression.init(pattern: "^[-]+[a-zA-Z]", options: [])

for argument in args {

    // Ignore the first comand line argument
    if argCount == 0 {
        argCount += 1
        continue
    }

    // Are we expecting a value? If so 'argValue' is not zero
    if argValue != 0 {
        // Make sure we have a value to read, ie. the current arg is not a switch or flag
        let range: NSRange = cmdRegExp.rangeOfFirstMatch(in: argument, options: [], range: NSMakeRange(0, argument.count))
        if range.location != NSNotFound {
            Stdio.reportErrorAndExit("Missing value for \(prevArg)")
        }

        switch argValue {
            case 1:
                sourcePath = argument
            case 2:
                destPath = argument
            case 3:
                padColour = Imageprep.processColour(argument)
            case 4:
                dpi = Float(argument) ?? 150.0
                if dpi == 0.0 {
                    Stdio.reportErrorAndExit("Invalid DPI value selected: 0.0")
                }
            case 5:
                newFormatForSips = Imageprep.processFormat(argument)
            case 6:
                actionType = Imageprep.processActionType(argument)
            case 7:
                // Set widths based on action and set the action flag if the value is good
                if actionType == "c" {
                    cropWidth = Imageprep.processActionValue(argument, actionType, true)
                } else if actionType == "s" {
                    scaleWidth = Imageprep.processActionValue(argument, actionType, true)
                } else {
                    padWidth = Imageprep.processActionValue(argument, actionType, true)
                }
            case 8:
                // Set heights based on action, but clear the action flag if the value is bad
                if actionType == "c" {
                    cropHeight = Imageprep.processActionValue(argument, actionType, false)
                    Imageprep.addAction("-c", cropWidth, cropHeight)
                } else if actionType == "s" {
                    scaleHeight = Imageprep.processActionValue(argument, actionType, false)
                    Imageprep.addAction("-z", scaleWidth, scaleHeight)
                } else {
                    padHeight = Imageprep.processActionValue(argument, actionType, false)
                    Imageprep.addAction("-p", padWidth, padHeight)
                }
            case 9:
                // Set crop offset: will be a value in range 0-8
                cropFix = Imageprep.processCropFix(argument)
            case 10:
                // FROM 6.3.0
                // Set specific crop offset
                cropFix = 4
                cropLeft = Imageprep.processCropOffset(argument)
            case 11:
                cropDown = Imageprep.processCropOffset(argument)
            case 12:
                // FROM 7.0.0
                jpegCompression = Imageprep.processCompressionLevel(argument)
            default:
                Stdio.reportErrorAndExit("Unknown value: \(argument)")
        }

        if argValue == 6 || argValue == 7 || argValue == 10 {
            argValue += 1
        } else {
            argValue = 0
        }
    } else {
        // Parse the next non-value argument
        switch argument.lowercased() {
            case "-s":
                fallthrough
            case "--source":
                argValue = 1
            case "-d":
                fallthrough
            case "--destination":
                argValue = 2
            case "-c":
                fallthrough
            case "--color":
                fallthrough
            case "--colour":
                argValue = 3
            case "-r":
                fallthrough
            case "--resolution":
                argValue = 4
                doChangeResolution = true
            case "-f":
                fallthrough
            case "--format":
                argValue = 5
                doReformat = true
            case "-a":
                fallthrough
            case "--action":
                argValue = 6
            case "-q":
                fallthrough
            case "--quiet":
                doShowMessages = false
            /*
            case "-k":
                fallthrough
            case "--keep":
                doDeleteSource = false
            */
            case "-x":
                // FROM 7.0.0
                doDeleteSource = true
            case "-o":
                fallthrough
            case "--overwrite":
                doOverwrite = true
            case "--createdirs":
                doMakeSubDirectories = true
            case "--info":
                justInfo = true
            case "--cropfrom":
                argValue = 9
            case "--offset":
                argValue = 10
            // FROM 7.0.0
            case "--jpeg":
                fallthrough
            case "-j":
                argValue = 12
            case "-h":
                fallthrough
            case "--help":
                showHelp()
                Stdio.disableCtrlHandler()
                exit(EXIT_SUCCESS)
            case "--version":
                showHeader()
                Stdio.disableCtrlHandler()
                exit(EXIT_SUCCESS)
            default:
                // FROM 7.0.0
                // Check for a command -- other items can be saved as possible files
                let range: NSRange = cmdRegExp.rangeOfFirstMatch(in: argument, options: [], range: NSMakeRange(0, argument.count))
                if range.location != NSNotFound {
                    Stdio.reportErrorAndExit("Unknown argument: \(argument)")
                }

                // Assume the value is a source file for now -- we'll check them later
                sourceFiles.append(argument)
        }

        prevArg = argument
    }

    argCount += 1

    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argValue > 0 {
        Stdio.reportErrorAndExit("Missing value for \(argument)")
    }
}

// Has anything been done?
if actions.count == 0 && !doReformat && !doChangeResolution && !justInfo {
    Stdio.reportErrorAndExit("No actions specified")
}

/*
 * SOURCE PATH(S) CHECKS
 */

// FROM 7.0.0
// Check for any passed source files
// NOTE These will override the -s flag value
if sourceFiles.count > 0 {
    var index: Int = 0
    while (true)  {
        // Reached the end of the list? Then exit
        if index >= sourceFiles.count {
            break
        }

        let file: String = Path.getFullPath(sourceFiles[index])
        sourceFiles[index] = file

        // Check the referenced file exists. If it doesn't, remove it from the list
        // and then restart the loop to get the next item if there is one
        if !fm.fileExists(atPath: file, isDirectory: &sourceIsdirectory) {
            Stdio.reportWarning("Source \(file) cannot be found")
            sourceFiles.remove(at: index)
            continue
        }

        // Check the referenced file isn't a directory. If it is, remove it from the list
        // and then restart the loop to get the next item if there is one
        if sourceIsdirectory.boolValue {
            Stdio.reportWarning("Source \(file) is a directory -- use the -s flag to add a directory as a source")
            sourceFiles.remove(at: index)
            continue
        }

        index += 1
    }

    // Clear `sourcePath` -- see `processFile()`
    sourcePath = ""
    sourceIsdirectory = false
} else {
    // Get the full source path
    // NOTE It may point to a single file
    sourcePath = Path.getFullPath(sourcePath)

    // Check whether the source is a directory or a file,
    // and if neither exists, bail
    if !fm.fileExists(atPath: sourcePath, isDirectory: &sourceIsdirectory) {
        Stdio.reportErrorAndExit("Source \(sourcePath) cannot be found")
    }

    // If the source points to a file, add it to the list of passed files
    if !sourceIsdirectory.boolValue {
        //sourceFile = (sourcePath as NSString).lastPathComponent
        //sourcePath = (sourcePath as NSString).deletingLastPathComponent
        sourceFiles.append(sourcePath)
        sourcePath = ""
    }
}

/*
 * DESTINATION PATH CHECKS
 */

// Get full destination path
// NOTE It may point to a single file, but this is only
//      valid if `sourceFiles` contains a single file
destPath = Path.getFullPath(destPath)

// Check whether the destination is a directory or a file
if !fm.fileExists(atPath: destPath, isDirectory: &destIsdirectory) {
    // Destination is missing but this is valid if the destination is a file,
    // or an as-yet-uncreated directory, so check its extension before bailing
    if (destPath as NSString).pathExtension.count == 0 {
        // No file extension, ergo this is a directory
        Imageprep.processDirectory(destPath)

        // If we've got this far, we have made the directory, so we need to
        // correctly set the directory check flag
        destIsdirectory = true
    }
}

// If the destination points to a file, get the components
if !destIsdirectory.boolValue {
    // The source points to a file, so extract the file
    destFile = (destPath as NSString).lastPathComponent
    destPath = (destPath as NSString).deletingLastPathComponent

    // If the file doesn't exist, create directories that lead to
    // where it's going to be placed
    if !fm.fileExists(atPath: destPath) {
        Imageprep.processDirectory(destPath)
    }
}

// If the source is a directory and the target is a file, that's a mismatch
// we can't resolve, so warn and bail
if !destIsdirectory.boolValue {
    if sourceIsdirectory.boolValue {
        Stdio.reportErrorAndExit("Source (dirctory) and destination (file) are mismatched")
    }

    // FROM 7.0.0
    // We can only accept a destination file if there's only one file on the list
    if sourceFiles.count > 1 {
        Stdio.reportErrorAndExit("Source files require a directory destination")
    }
}

/*
 * DON'T DELETE SOURCE FILE(S) CHECKS
 */

// Auto-enable 'keep files' if the source and destination are the same
if sourcePath == destPath && (sourceFile == destFile || (sourceFile != "" && destFile == "")) {
    doDeleteSource = false
}

// FROM 7.0.0
// Make sure we don't delete single files if the named destination file matches, or
// the destination directory is the same as the source
if sourceFiles.count == 1 {
    if !destIsdirectory.boolValue && sourceFiles[0] == destPath + "/" + destFile {
        doDeleteSource = false
    }

    if destIsdirectory.boolValue && destPath == (sourceFiles[0] as NSString).deletingLastPathComponent {
        doDeleteSource = false
    }
}

// FROM 7.0.0
// Make sure we don't delete added files if the named destination is
// the same directory as the source. The files may be in very different
// locations, so for now if one's source matches, don't delete any of them
if sourceFiles.count > 1 {
    // `destPath` has already been checked that it doesn't point to a file
    // so no need to recheck it here
    for file: String in sourceFiles {
        if destPath == (file as NSString).deletingLastPathComponent {
            doDeleteSource = false
            break
        }
    }
}

/*
 * INFORMATIION OUTPUT
 */

// Output the source and destination directories
if doShowMessages {
    if sourceIsdirectory.boolValue {
        Stdio.report("Source: \(sourcePath)/" + (sourceFile.count > 0 ? "\(sourceFile)" : ""))
    } else {
        Stdio.report("Sources: \(sourceFiles.count) \(sourceFiles.count == 1 ? "file" : "files")")
    }

    Stdio.report("Target: \(destPath)/" + (destFile.count > 0 ? "\(destFile)" : ""))
    if doChangeResolution { Stdio.report("New DPI: \(dpi)") }
    if doReformat { Stdio.report("New image format: \(newFormatForSips)") }
    if doDeleteSource { Stdio.report("Will delete source image(s)") }
    Stdio.report("Compression for JPEGs: \(jpegCompression)")
}

/*
 * FILE PROCESSING
 */

// Split the path for a single source file or source directory
if sourceIsdirectory.boolValue {
    // Source file is a directory, so enumerate its contents
    // and then process all the files, one by one
    do {
        let contents: [String] = try fm.contentsOfDirectory(atPath: sourcePath)

        // If there are no contents, bail
        if contents.count == 0 {
            Stdio.reportWarning("Source directory \(sourcePath) is empty")
            Stdio.disableCtrlHandler()
            exit(EXIT_SUCCESS)
        }

        // Otherwise proceess each item - 'processFile()' determines suitability
        for file: String in contents.sorted() {
            // FROM 7.0.0 `processFile()` expects a full path
            Imageprep.processFile(sourcePath + "/" + file)
        }
    } catch {
        Stdio.reportErrorAndExit("Unable to get contents of source directory \(sourcePath)")
    }
} else {
    // FROM 7.0.0
    // Run through source files added as arguments
    if sourceFiles.count > 0 {
        for file: String in sourceFiles {
            // FROM 7.0.0 `processFile()` expects a full path
            Imageprep.processFile(file)
        }
    }
}

/*
 * OUTCOME OUTPUT
 */

// Present a final task report, if requested
if doShowMessages {
    if fileCount == 1 {
        Stdio.report("1 file converted")
    } else if fileCount > 1 {
        Stdio.report("\(fileCount) files converted")
    } else {
        Stdio.report("No files converted")
    }
}

// Tidy up
if actions.count > 0 {
    actions.removeAllObjects()
}

// And done...
Stdio.disableCtrlHandler()
exit(EXIT_SUCCESS)


// MARK: Help and Info Functions

/**
 Display the app's help information
 */
func showHelp() {

    // Display the version info
    showHeader()

    // Get the list of suported formats, ignoring similarly named ones
    var formats: String = ""
    for i: Int in 0..<DEDUPE_INDEX {
        formats += (SUPPORTED_TYPES[i].uppercased() + (i < DEDUPE_INDEX - 1 ? ", " : ""))
    }

    Stdio.report("\nA macOS image preparation utility.\r\n")
    Stdio.report("\(String(.bold))USAGE\(String(.normal))\n    imageprep [-s path] [-d path] [-c pad_colour]")
    Stdio.report("              [-a s scale_height scale_width] [-a p pad_height pad_width]")
    Stdio.report("              [-a c crop_height crop_width] [--cropfrom point] [-r] [-f] [-x]")
    Stdio.report("              [-o] [-h] [--info] [--createdirs] [--version]\n")
    Stdio.report("    Image formats supported: \(formats).\n")
    Stdio.report("\(String(.bold))OPTIONS\(String(.normal))")
    Stdio.report("    -s | --source      {path}                  The path to an image or a directory of images.")
    Stdio.report("                                               Default: current working directory.")
    Stdio.report("    -d | --destination {path}                  The path to the images. Default: source directory.")
    Stdio.report("    -a | --action      {type} {width} {height} The crop/pad dimensions. Type is s (scale), c (crop) or p (pad).")
    Stdio.report("                                               Provide absolute integer values for width or height, or")
    Stdio.report("                                               x to use the image's existing dimension, or m to maintain")
    Stdio.report("                                               the source image's aspect ratio")
    Stdio.report("    -c | --colour      {colour}                The padding colour in Hex, eg. A1B2C3. Default: FFFFFF.")
    Stdio.report("         --cropfrom    {point}                 Anchor point for crop actions. Use tr for top right, cl for")
    Stdio.report("                                               centre left, br for bottom right, etc.")
    Stdio.report("         --offset      {x} {y}                 Specify a top-left co-ordinate for the crop origin.")
    Stdio.report("                                               This setting will be overridden by --cropfrom")
    Stdio.report("    -r | --resolution  {dpi}                   Set the image dpi, eg. 300.")
    Stdio.report("    -f | --format      {format}                Set the image format (see above).")
    Stdio.report("    -j | --jpeg        {level}                 Set the compression level of any saved JPEG images as a percentage.")
    Stdio.report("                                               Default: 80")
    Stdio.report("    -o | --overwrite                           Overwrite an existing file. Without this, existing files will be kept.")
    Stdio.report("    -x                                         Delete the source file. Without this, the source will be retained.")
    Stdio.report("         --createdirs                          Make target intermediate directories if they do not exist.")
    Stdio.report("         --info                                Export basic image info: path, height, width, dpi and alpha.")
    Stdio.report("    -q | --quiet                               Silence output messages (errors excepted).")
    Stdio.report("    -h | --help                                This help screen.")
    Stdio.report("         --version                             Version information.\n")
    Stdio.report("\(String(.bold))EXAMPLES\(String(.normal))")
    Stdio.report("    Convert files in the current directory to JPEG and to 300dpi:\n")
    Stdio.report("        imageprep -f jpeg -r 300\n")
    Stdio.report("    Scale to 128 x 128, keeping the originals:\n")
    Stdio.report("        imageprep -s $SOURCE -d $DEST -a s 128 128\n")
    Stdio.report("    Scale to height of 1024, width in aspect, keeping the originals:\n")
    Stdio.report("        imageprep -s $SOURCE -d $DEST -a s m 1024\n")
    Stdio.report("    Crop files to 1000 x 100, making intermediate directories, keeping originals:\n")
    Stdio.report("        imageprep -s $SOURCE -d $DEST --createdirs -a c 1000 1000\n")
    Stdio.report("    Crop files to 1000 x source image height, keeping originals:\n")
    Stdio.report("        imageprep -s $SOURCE -d $DEST -a c 1000 x\n")
    Stdio.report("    Crop files to 500 x 500, anchored at top right, deleting the originals:\n")
    Stdio.report("        imageprep -s $SOURCE -d $DEST -a c 500 500 --cropfrom tr -x\n")
    Stdio.report("    Pad to 2000 x 2000 with magenta, deleting the originals:\n")
    Stdio.report("        imageprep -s $SOURCE -d $DEST -a p 2000 2000 -c ff00ff -x\n")
    Stdio.report("\(String(.italic))https://smittytone.net/imageprep/index.html\(String(.normal))")
}


/**
 Display the app's version number.
 */
func showHeader() {

    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build: String   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    let name: String    = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    Stdio.report("\(String(.bold))\(name) \(version) (\(build))\(String(.normal))")
    Stdio.report("Copyright © 2025, Tony Smith (@smittytone). Source code available under the MIT licence.")
}
