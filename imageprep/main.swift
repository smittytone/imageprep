/*
    imageprep
    main.swift

    Copyright © 2023 Tony Smith. All rights reserved.

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


// MARK: - Constants

let SUPPORTED_TYPES: [String]   = ["png", "jpeg", "tiff", "pict", "bmp", "gif", "jpg", "tif"]
let DEDUPE_INDEX: Int           = 6
let EMPTY_HEX_BYTES: String     = "000000"

// FROM 6.1.0 -- Use stderr, stdout for output
let STD_ERR: FileHandle         = FileHandle.standardError
let STD_OUT: FileHandle         = FileHandle.standardOutput
let STD_IN: FileHandle          = FileHandle.standardInput

// FROM 6.1.0 -- TTY formatting
let RED: String                 = "\u{001B}[31m"
let YELLOW: String              = "\u{001B}[33m"
let RESET: String               = "\u{001B}[0m"
let BOLD: String                = "\u{001B}[1m"
let ITALIC: String              = "\u{001B}[3m"
let BSP: String                 = String(UnicodeScalar(8))

// FROM 6.2.0
let BASE_DPI: CGFloat           = 72.0
let USE_IMAGE: Int              = -1
let SCALE_TO_WIDTH: Int         = -2
let SCALE_TO_HEIGHT: Int        = -3
let ACTION_TYPES: [String]      = ["c", "s", "p"]
// FROM 6.3.3
let CTRL_C_MSG: String          = "\(BSP)\(BSP)\rimageprep interrupted -- halting"
let EXIT_CTRL_C_CODE: Int32     = 130


// MARK: - Global Variables

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
var doDeleteSource: Bool        = true
var actions: NSMutableArray     = NSMutableArray.init()
// FROM 6.2.0
var justInfo: Bool              = false
var cropFix: Int                = 4
// FROM 6.3.0
var cropLeft: Int               = -1
var cropDown: Int               = -1
// FROM 6.4.0
var sourceFiles: [String]       = []

// CLI argument management
var argValue: Int               = 0
var argCount: Int               = 0
var actionType: String          = "c"
var prevArg: String             = ""
var fileCount: Int              = 0


// MARK: - Functions

/**
 Convert a partial path to an absolute path.
 
 - Parameters:
    - relativePath: A relative path, ie. contains `../` or lacks a `/` prefix.
 
 - Returns: An absolute path as a string.
 */
func getFullPath(_ relativePath: String) -> String {

    // Standardise the path as best as we can (this covers most cases)
    var absolutePath: String = (relativePath as NSString).standardizingPath

    // Check for a unresolved relative path -- and if it is one, resolve it
    // NOTE This includes raw filenames
    if (absolutePath as NSString).contains("..") || !(absolutePath as NSString).hasPrefix("/") {
        absolutePath = processRelativePath(absolutePath)
    }

    // Return the absolute path
    return absolutePath
}


/**
 Add the basepath (the current working directory of the call) to the
 supplied relative path - and then resolve it.
 
 - Parameters:
    - relativePath: A relative path, ie. contains `../` or lacks a `/` prefix.
 
 - Returns: An absolute path as a string.
 */
func processRelativePath(_ relativePath: String) -> String {

    let absolutePath: String = fm.currentDirectoryPath + "/" + relativePath
    return (absolutePath as NSString).standardizingPath
}


/**
 Load the specified image and gather data from it.
 
 - Parameters:
    - path: An image file path.
 
 - Returns: An ImageInfo object, or `nil` on error.
 */
func getImageInfo(_ path: String) -> ImageInfo? {

    // Read the target file in as data and check its length
    let data: Data = fm.contents(atPath: path) ?? Data.init(count: 0)
    if data.count == 0 {
        return nil
    }

    // Create an ImageInfo instance and populate it using an NSBitmapImageRep
    // created from the data we just loaded
    return ImageInfo(data)
}


/**
 If we are to create all the directories to 'path', attempt to do so,
 or just bail in other cases.
 
 - Parameters:
    - path: An image file path.
 */
func processDirectory(_ path: String) {

    if doMakeSubDirectories {
        // Try to create the path to the specified directory
        do {
            try fm.createDirectory(at: URL.init(fileURLWithPath: path),
                                   withIntermediateDirectories: true,
                                   attributes: nil)
        } catch {
            reportErrorAndExit("Destination \(path) does not exist and cannot be created")
        }
    } else {
        // Directory doesn't exist, we've not been told to create it, so bail
        reportErrorAndExit("Destination \(destPath) cannot be found")
    }
}


/**
 Process a single source-image file.
 
 FROM 6.4.0 `file` is a full path including a file name
 
 - Parameters:
    - file: An image file path.
 */
func processFile(_ file: String) {

    // Get the file extension
    let ext: String = (file.lowercased() as NSString).pathExtension
    // FROM 6.4.0
    let fileName = (file as NSString).lastPathComponent
    //let filePath = (file as NSString).deletingLastPathComponent

    // Only proceed if we have a file of the correct extension
    if !SUPPORTED_TYPES.contains(ext) { return }

    // Determine the file's output file path
    var outputFile: String = destPath + "/"
    if destIsdirectory.boolValue {
        // Target is a directory, so add the file name
        outputFile += fileName
    } else {
        // Destination is a specified file
        outputFile += destFile
    }

    /* Get the full source image path
    var inputFile: String = "\(file)"
    if sourcePath.count > 0 {
        inputFile = "\(sourcePath)/" + inputFile
    }
     */

    // Check the source image by loading it and getting image info
    let imageInfo: ImageInfo? = getImageInfo(file)
    if imageInfo == nil {
        reportWarning("File \(fileName) has no content -- skipping")
        return
    }

    if justInfo {
        // User just wants file data, so output it and exit
        let hasAlpha: String = imageInfo!.hasAlpha ? "alpha" : "no-alpha"
        writeToStdout("\(file) \(imageInfo!.width) \(imageInfo!.height) \(imageInfo!.dpi) \(imageInfo!.aspectRatio) " + hasAlpha)
        return
    }

    // Set the temporary work file path
    let tmpFile: String = outputFile + ".sipstmp"

    // Make the temporary work file. It's a TIFF so we need to
    // check the source image type first
    if ext == "tif" || ext == "tiff" {
        // Source image IS a TIFF...
        if file != outputFile {
            // ...but it's not at the same location as the output file,
            // so just copy it across
            do {
               try fm.copyItem(at: URL.init(fileURLWithPath: file),
                               to: URL.init(fileURLWithPath: tmpFile))
            } catch {
                reportWarning("Could not write \(outputFile) -- skipping")
                return
            }
        }
    }  else {
        // The source is not a TIFF, so just create the temp file
        runSips([file, "-s", "format", "tiff", "--out", tmpFile])
    }

    // First process actions on the temporary work file
    if actions.count > 0 {
        for i: Int in 0..<actions.count {
            let action: Action = actions.object(at: i) as! Action

            // FROM 6.2.0
            // Calculate actual width and height of final image based on input
            // Set width, height appropriately: first for raw image valiues...
            var width: Int = action.width == USE_IMAGE ? imageInfo!.width : action.width
            var height: Int = action.height == USE_IMAGE ? imageInfo!.height : action.height

            // ...then for aspect ratio
            width = action.width == SCALE_TO_HEIGHT ? Int(CGFloat(action.height) * imageInfo!.aspectRatio) : width
            height = action.height == SCALE_TO_WIDTH ? Int(CGFloat(action.width) / imageInfo!.aspectRatio) : height

            // Set up sips' arguments
            var sipsArgs: [String] = [tmpFile, action.type, "\(height)", "\(width)"]

            if action.type != "-z" {
                if action.type == "-c" {
                    if cropFix != 4 {
                        // Calculate the x and y offsets and add --cropOffset to the command array
                        var xOffset: Int = 0
                        var yOffset: Int = 0

                        if cropFix > 2 {
                            yOffset = imageInfo!.height - height
                        }

                        if cropFix == 3 || cropFix == 5 {
                            yOffset = yOffset >> 1
                        }

                        if cropFix % 3 != 0 {
                            xOffset = imageInfo!.width - width
                        }

                        if cropFix == 1 || cropFix == 7 {
                            xOffset = xOffset >> 1
                        }

                        // FROM 6.3.1
                        // Deal with sips zero offset issue with a function
                        sipsArgs.append(contentsOf: ["--cropOffset", "\(sipsOffsetfix(yOffset))", "\(sipsOffsetfix(xOffset))"])
                    } else if cropLeft != -1 && cropDown != -1 {
                        sipsArgs.append(contentsOf: ["--cropOffset", "\(sipsOffsetfix(cropDown))", "\(sipsOffsetfix(cropLeft))"])
                    }
                }

                // Don't add a pad colour to a scale to avoid losing alpha
                sipsArgs.append(contentsOf: ["--padColor", action.colour])
            }

            // Apply the action
            runSips(sipsArgs)
        }
    }

    // Set the DPI, if requested
    if doChangeResolution {
        runSips([tmpFile, "-s", "dpiHeight", "\(dpi)", "-s", "dpiWidth", "\(dpi)"])
    }

    // Set the image format, if requested
    if doReformat {
        // Whatever the image type, we output the new format
        // as a new file with the correct extension
        let newOutputFile: String = (outputFile as NSString).deletingPathExtension + "." + formatExtension

        if fm.fileExists(atPath: newOutputFile) && !doOverwrite {
            // Uh oh! There's already a file there and we have not set the 'do overwrite' flag
            reportWarning("target file \(newOutputFile) already exists -- skipping")
            return
        }

        // Create new-format file from the work file
        runSips([tmpFile, "-s", "format", newFormatForSips, "--out", newOutputFile])
        outputFile = newOutputFile
    } else {
        // We're not reformatting the file, so write it back
        // using the source type (by its file extension)
        runSips([tmpFile, "-s", "format", processFormat(ext), "--out", outputFile])
    }

    // Remove the temporary work file now we're done
    let success: Bool = removeFile(tmpFile)
    if !success {
        reportWarning("Could not delete temporary file \(tmpFile) after processing")
    }

    // Remove the source file, if requested
    if doDeleteSource {
        let success: Bool = removeFile(file)
        if !success {
            reportWarning("Could not delete source file \(fileName) after processing")
        }
    }

    // Increment the file counter
    fileCount += 1

    // Report process
    report("Image \(file) processed to \(outputFile)...")
}


/**
 Generic file remover called from `processFile()`.
 
 - Parameters:
    - path: An image file path.
 
 - Returns: `true` if the operation succeeded, otherwise `false`.
 */
func removeFile(_ path: String) -> Bool {

    do {
        try fm.removeItem(at: URL.init(fileURLWithPath: path))
    } catch {
        return false
    }
    
    return true
}


/**
 Call `sips` using Process.
 
 - Parameters:
    - args: An array of `sips` arguments.
 */
func runSips(_ args: [String]) {

    let task: Process = Process()
    task.executableURL = URL.init(fileURLWithPath: "/usr/bin/sips")
    if args.count > 0 { task.arguments = args }

    // Pipe out the output to avoid putting it in the log
    let outputPipe: Pipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = outputPipe

    do {
        try task.run()
    } catch {
        reportErrorAndExit("Cannot locate sips")
    }

    // Block until the task has completed (short tasks ONLY)
    task.waitUntilExit()
    
    // Look for and deal with execution issues
    if !task.isRunning {
        if (task.terminationStatus != 0) {
            // Command failed -- collect the output if there is any
            let outputHandle: FileHandle = outputPipe.fileHandleForReading
            var outString: String = ""
            if outputHandle.availableData.count > 0 {
                outString = String(data: outputHandle.availableData, encoding: String.Encoding.utf8) ?? ""
            }

            if outString.count > 0 {
                reportError("sips reported an error: \(outString)")
            } else {
                reportError("sips reported error code \(task.terminationStatus) -- task not completed")
            }
        }
    }
}


/**
 `sips` shows incorrect behaviour when `--cropOffset` values are zero,
 but it can handle fractional values, so convert the former to the
 latter.
 
 FROM 6.3.1
 
 - Parameters:
    - offsetValue: The integer value we are converting.
 
 - Returns: The offset value as a float.
 */
func sipsOffsetfix(_ offsetValue: Int) -> Float {
    
    if offsetValue == 0 {
        return 0.0001
    }
    
    return Float(offsetValue)
}


/**
 Generic message display routine.
 
 Relies on global `doShowMessage`.
 
 - Parameters:
    - message: The string to output.
 */
func report(_ message: String) {

    if doShowMessages {
        writeToStderr(message)
    }
}


/**
 Generic warning display routine.
 
 Does not exit on completion.
 
 - Parameters:
    - message: The string to output.
 */
func reportWarning(_ message: String) {

    writeToStderr(YELLOW + BOLD + "WARNING" + RESET + " " + message)
}


/**
 Generic error display routine.
 
 Does not exit on completion.
 
 - Parameters:
    - message: The string to output.
 */
func reportError(_ message: String) {

    writeToStderr(RED + BOLD + "ERROR" + RESET + " " + message)
}


/**
 Generic error display routine.
 
 Exits app on completion.
 
 - Parameters:
    - message: The string to output.
    - code:    The exit code to issue. Default: `EXIT_FAILURE`.
 */
func reportErrorAndExit(_ message: String, _ code: Int32 = EXIT_FAILURE) {

    writeToStderr(RED + BOLD + "ERROR " + RESET + message + " -- exiting")
    exit(code)
}


/**
 Write errors and other messages to `stderr`.
 
 - Parameters:
    - message: The string to output.
 */
func writeToStderr(_ message: String) {

    writeOut(STD_ERR, message)
}


/**
 Write result data and app output to `stdout`.
 
 - Parameters:
    - output: The string to output.
 */
func writeToStdout(_ output: String) {

    writeOut(STD_OUT, output)
}


/**
 Write a string to the specified file handle.
 
 - Parameters:
    - fileHandle: The target file handle, eg. `STDERR`.
    - message:    The string to be written.
 */
func writeOut(_ fileHandle: FileHandle, _ message: String) {
    
    let outputString: String = message + "\r\n"
    if let outputData: Data = outputString.data(using: .utf8) {
        fileHandle.write(outputData)
    }
}


/**
 Validate a user-supplied colour value.
 
 Check that the value is in hex, and clean it up for `sips`.
 
 - Parameters:
    - colourString: The colour value as a String.
 
 - Returns: The corrected colour value as a String.
 */
func processColour(_ colourString: String) -> String {

    var workColour: String = colourString

    // Remove any likely preceeding hex markers
    while true {
        var match: Bool = false

        for prefixString: String in ["#", "0x", "\\x", "x", "$"] {
            if (workColour as NSString).hasPrefix(prefixString) {
                workColour = String(workColour.suffix(workColour.count - prefixString.count))
                match = true
            }
        }

        if !match { break }
    }

    // Check for an out-of-range value
    if workColour.count > 6 {
        reportErrorAndExit("Invalid hex colour value supplied \(colourString)")
    }

    // Check it's actually hex (or makes sense as hex)
    let scanner: Scanner = Scanner.init(string: workColour)
    var dummy: UInt64 = 0
    if !scanner.scanHexInt64(&dummy) {
        reportErrorAndExit("Invalid hex colour value supplied \(colourString)")
    }

    // Pre-pad the hex string up to six characters
    if workColour.count < 6 {
        workColour = String(EMPTY_HEX_BYTES.prefix(6 - workColour.count)) + workColour
    }

    return workColour
}


/**
 Validate a user-supplied file type.
 
 Make sure a correct format has been passed, and adjust
 it if for `sips` use, eg. `JPG` -> `jpeg`, `tif` -> `tiff`, etc.
 
 - Parameters:
    - format: The file format as a String.
 
 - Returns: The corrected format as a String.
 */
func processFormat(_ format: String) -> String {

    // Store the expected format as provided by the user --
    // this is later used to set the target's file extension
    formatExtension = format
    var workFormat: String = format.lowercased()

    // If we don't have a good format, bail
    if !SUPPORTED_TYPES.contains(workFormat) {
        reportErrorAndExit("Invalid image format selected: \(workFormat)")
    }

    // Handle duplicate extensions
    if workFormat == "jpg" {
        workFormat = "jpeg"
    } else if workFormat == "tif" {
        workFormat = "tiff"
    }

    return workFormat
}


/**
 Validate a user-supplied image-processing action's type.
 
 - Parameters:
    - arg: The action specification CLI argument.
 
 - Returns: The corrected action marker as a lower case String.
 */
func processActionType(_ arg: String) -> String {

    let workArg: String = arg.lowercased()

    if !ACTION_TYPES.contains(workArg) {
        reportErrorAndExit("Invalid action selected: \(arg)")
    }

    return workArg
}


/**
 Validate a user-supplied image-processing action's settings.
 
 The app will exit on an invalid setting.
 
 - Parameters:
    - arg:     The action setting CLI argument.
    - action:  The action the setting relates to.
    - isWidth: Is this an image-width setting?
 
 - Returns: The corrected setting value as an integer.
 */
func processActionValue(_ arg: String, _ action: String, _ isWidth: Bool) -> Int {

    if arg.lowercased() == "x" {
        // User wants to retain the image's native value
        return USE_IMAGE
    }

    if arg.lowercased() == "m" {
        // User wants a dimension determined by
        // the source image's aspect ratio
        return isWidth ? SCALE_TO_HEIGHT : SCALE_TO_WIDTH
    }

    let value: Int = Int(arg) ?? 0
    if value < 1 {
        let theValue: String = isWidth ? "width" : "height"
        let theAction: String = getActionName(action)
        reportErrorAndExit("Invalid \(theAction) \(theValue) value")
    }

    return value
}


/**
 Validate a user-supplied action and add it to the list of actions to be performed on each image.
 
 Ensure that if, for example, both height and width are image native, we don't need to do
 anything.
 
 - Parameters:
    - action: The user-specified action, eg. `c` for 'crop'.
    - width:  The target image-width.
    - height: The target image-height.
 */
func addAction(_ action: String, _ width: Int, _ height: Int) {

    if (width == USE_IMAGE && height == USE_IMAGE) || (width == SCALE_TO_HEIGHT && height == SCALE_TO_WIDTH) {
        let theAction: String = getActionName(action)
        reportWarning("Action \(theAction) will not change the image -- ignoring")
        return
    }
    
    // Add the action to the list of those we'll perform
    actions.add(Action.init(action, width, height, padColour))
}


/**
 Return a human-readable action name.
 
 For example, `c` is returned as `crop`, `s` as `scale`, `p` as `pad`.
 
 - Parameters:
    - action: The action code.
 
 - Returns: The action's human-readable name.
 */
func getActionName(_ action: String) -> String {

    var theAction: String = "crop"
    if action == "s" || action == "-z" { theAction = "scale" }
    if action == "p" || action == "-p"  { theAction = "pad" }
    return theAction
}


/**
 Validate a user-specified crop anchor point value.
 
 Converts textual anchor point identifiers to their numeric equivalents,
 eg. `br` (bottom right) -> `8`.
 
 The app will exit on an invalid value.
 
 - Parameters:
    - arg: The anchor point CLI argument.
 
 - Returns: The decoded anchor point as an integer.
 */
func processCropFix(_ arg: String) -> Int {

    let workArg: String = arg.lowercased()

    // Check for a numeric value
    var value: Int = Int(workArg) ?? -99
    if value == -99 {
        // 'arg' is textual, eg. 'tr', so convert to a value
        if workArg.hasPrefix("t") { value = 0 }
        if workArg.hasPrefix("c") { value = 3 }
        if workArg.hasPrefix("b") { value = 6 }

        if workArg.hasSuffix("l") { value += 0 }
        if workArg.hasSuffix("c") { value += 1 }
        if workArg.hasSuffix("r") { value += 2 }
    }

    // If there was no text match, throw an error
    if value < 0 || value > 8 {
        reportErrorAndExit("Invalid crop anchor point: \(arg)")
    }

    return value
}


/**
 Validate a user-specified crop anchor point value.
 
 Converts textual anchor point identifiers to their numeric equivalents,
 eg. `br` (bottom right) -> `8`.
 
 The app will exit on an invalid value.
 
 FROM 6.3.0
 
 - Parameters:
    - arg: The anchor offset CLI argument.
 
 - Returns: The anchor offset as an integer.
 */
func processCropOffset(_ arg: String) -> Int {
    
    let workArg: String = arg.lowercased()
    let value: Int = Int(workArg) ?? -99
    if value < 0 {
        reportErrorAndExit("Invalid crop offset: \(arg)")
    }
    
    return value
}


/**
 Display the app's help information.
 */
func showHelp() {

    // Display the version info
    showHeader()

    // Get the list of suported formats, ignoring similarly named ones
    var formats: String = ""
    for i: Int in 0..<DEDUPE_INDEX {
        formats += (SUPPORTED_TYPES[i].uppercased() + (i < DEDUPE_INDEX - 1 ? ", " : ""))
    }

    writeToStdout("\nA macOS image preparation utility.\r\n" + ITALIC + "https://smittytone.net/imageprep/index.html\n" + RESET)
    writeToStdout(BOLD + "USAGE" + RESET + "\n    imageprep [-s path] [-d path] [-c pad_colour]")
    writeToStdout("              [-a s scale_height scale_width] [-a p pad_height pad_width]")
    writeToStdout("              [-a c crop_height crop_width] [--cropfrom point] [-r] [-f] [-k]")
    writeToStdout("              [-o] [-h] [--info] [--createdirs] [--version]\n")
    writeToStdout("    Image formats supported: \(formats).\n")
    writeToStdout(BOLD + "OPTIONS" + RESET)
    writeToStdout("    -s | --source      {path}                  The path to an image or a directory of images.")
    writeToStdout("                                               Default: current working directory.")
    writeToStdout("    -d | --destination {path}                  The path to the images. Default: source directory.")
    writeToStdout("    -a | --action      {type} {width} {height} The crop/pad dimensions. Type is s (scale), c (crop) or p (pad).")
    writeToStdout("                                               Provide absolute integer values for width or height, or")
    writeToStdout("                                               x to use the image's existing dimension, or m to maintain")
    writeToStdout("                                               the source image's aspect ratio")
    writeToStdout("    -c | --colour      {colour}                The padding colour in Hex, eg. A1B2C3. Default: FFFFFF.")
    writeToStdout("         --cropfrom    {point}                 Anchor point for crop actions. Use tr for top right, cl for")
    writeToStdout("                                               centre left, br for bottom right, etc.")
    writeToStdout("         --offset      {x} {y}                 Specify a top-left co-ordinate for the crop origin.")
    writeToStdout("                                               This setting will be overridden by --cropfrom")
    writeToStdout("    -r | --resolution  {dpi}                   Set the image dpi, eg. 300.")
    writeToStdout("    -f | --format      {format}                Set the image format (see above).")
    writeToStdout("    -o | --overwrite                           Overwrite an existing file. Without this, existing files will be kept.")
    writeToStdout("    -k | --keep                                Keep the source file. Without this, the source will be deleted.")
    writeToStdout("         --createdirs                          Make target intermediate directories if they do not exist.")
    writeToStdout("         --info                                Export basic image info: path, height, width, dpi and alpha.")
    writeToStdout("    -q | --quiet                               Silence output messages (errors excepted).")
    writeToStdout("    -h | --help                                This help screen.")
    writeToStdout("         --version                             Version information.\n")
    writeToStdout(BOLD + "EXAMPLES" + RESET)
    writeToStdout("    Convert files in the current directory to JPEG and to 300dpi:\n")
    writeToStdout("        imageprep -f jpeg -r 300\n")
    writeToStdout("    Scale to 128 x 128, keeping the originals:\n")
    writeToStdout("        imageprep -s $SOURCE -d $DEST -a s 128 128 -k\n")
    writeToStdout("    Scale to height of 1024, width in aspect, keeping the originals:\n")
    writeToStdout("        imageprep -s $SOURCE -d $DEST -a s m 1024 -k\n")
    writeToStdout("    Crop files to 1000 x 100, making intermediate directories, keeping originals:\n")
    writeToStdout("        imageprep -s $SOURCE -d $DEST --createdirs -a c 1000 1000 -k\n")
    writeToStdout("    Crop files to 1000 x source image height, keeping originals:\n")
    writeToStdout("        imageprep -s $SOURCE -d $DEST -a c 1000 x -k\n")
    writeToStdout("    Crop files to 500 x 500, anchored at top right:\n")
    writeToStdout("        imageprep -s $SOURCE -d $DEST -a c 500 500 --cropfrom tr\n")
    writeToStdout("    Pad to 2000 x 2000 with magenta, deleting the originals:\n")
    writeToStdout("        imageprep -s $SOURCE -d $DEST -a p 2000 2000 -c ff00ff\n")
}


/**
 Display app version information
 */
func showVersion() {

    showHeader()
    writeToStdout("Copyright © 2023, Tony Smith (@smittytone).\r\nSource code available under the MIT licence.")
}


/**
 Display the app's version number
 */
func showHeader() {

    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build: String   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    let name: String    = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    writeToStdout("\(name) \(version) (\(build))")
}


// MARK: - Runtime Start

// FROM 6.1.0
// Trap ctrl-c
/*
signal(SIGINT) {
    theSignal in writeToStderr("\(BSP)\(BSP)\rimageprep interrupted -- halting")
    exit(EXIT_FAILURE)
}
*/

// FROM 6.3.2
// Make sure the signal does not terminate the application
signal(SIGINT, SIG_IGN)

// Set up an event source for SIGINT...
let dss: DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT,
                                                                queue: DispatchQueue.main)
// ...add an event handler (from above)...
dss.setEventHandler {
    writeToStderr(CTRL_C_MSG)
    exit(EXIT_CTRL_C_CODE)
}

// ...and start the event flow
dss.resume()

 
// FROM 6.1.0
// No arguments? Show Help
var args: [String] = CommandLine.arguments
if args.count == 1 {
    showHelp()
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
            reportErrorAndExit("Missing value for \(prevArg)")
        }
        
        switch argValue {
            case 1:
                sourcePath = argument
            case 2:
                destPath = argument
            case 3:
                padColour = processColour(argument)
            case 4:
                dpi = Float(argument) ?? 150.0
                if dpi == 0.0 {
                    reportErrorAndExit("Invalid DPI value selected: 0.0")
                }
            case 5:
                newFormatForSips = processFormat(argument)
            case 6:
                actionType = processActionType(argument)
            case 7:
                // Set widths based on action and set the action flag if the value is good
                if actionType == "c" {
                    cropWidth = processActionValue(argument, actionType, true)
                } else if actionType == "s" {
                    scaleWidth = processActionValue(argument, actionType, true)
                } else {
                    padWidth = processActionValue(argument, actionType, true)
                }
            case 8:
                // Set heights based on action, but clear the action flag if the value is bad
                if actionType == "c" {
                    cropHeight = processActionValue(argument, actionType, false)
                    addAction("-c", cropWidth, cropHeight)
                } else if actionType == "s" {
                    scaleHeight = processActionValue(argument, actionType, false)
                    addAction("-z", scaleWidth, scaleHeight)
                } else {
                    padHeight = processActionValue(argument, actionType, false)
                    addAction("-p", padWidth, padHeight)
                }
            case 9:
                // Set crop offset: will be a value in range 0-8
                cropFix = processCropFix(argument)
            case 10:
                // FROM 6.3.0
                // Set specific crop offset
                cropFix = 4
                cropLeft = processCropOffset(argument)
            case 11:
                cropDown = processCropOffset(argument)
            default:
                reportErrorAndExit("Unknown value: \(argument)")
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
            case "-k":
                fallthrough
            case "--keep":
                doDeleteSource = false
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
            case "-h":
                fallthrough
            case "--help":
                showHelp()
                exit(EXIT_SUCCESS)
            case "--version":
                showVersion()
                exit(EXIT_SUCCESS)
            default:
                // FROM 6.4.0
                // Check for a command -- other items can be saved as possible files
                let range: NSRange = cmdRegExp.rangeOfFirstMatch(in: argument, options: [], range: NSMakeRange(0, argument.count))
                if range.location != NSNotFound {
                    reportErrorAndExit("Unknown argument: \(argument)")
                }

                // Assume the value is a source file for now -- we'll check them later
                sourceFiles.append(argument)
        }

        prevArg = argument
    }

    argCount += 1

    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argValue > 0 {
        reportErrorAndExit("Missing value for \(argument)")
    }
}

// Has anything been done?
if actions.count == 0 && !doReformat && !doChangeResolution && !justInfo {
    reportErrorAndExit("No actions specified")
}

/*
 * SOURCE PATH(S) CHECKS
 */

// FROM 6.4.0
// Check for any passed source files
// NOTE These will override the -s flag value
if sourceFiles.count > 0 {
    var index: Int = 0
    while (true)  {
        // Reached the end of the list? Then exit
        if index >= sourceFiles.count {
            break
        }

        let file: String = getFullPath(sourceFiles[index])
        sourceFiles[index] = file

        // Check the referenced file exists. If it doesn't, remove it from the list
        // and then restart the loop to get the next item if there is one
        if !fm.fileExists(atPath: file, isDirectory: &sourceIsdirectory) {
            reportWarning("Source \(file) cannot be found")
            sourceFiles.remove(at: index)
            continue
        }

        // Check the referenced file isn't a directory. If it is, remove it from the list
        // and then restart the loop to get the next item if there is one
        if sourceIsdirectory.boolValue {
            reportWarning("Source \(file) is a directory -- use the -s flag to add a directory as a source")
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
    sourcePath = getFullPath(sourcePath)

    // Check whether the source is a directory or a file,
    // and if neither exists, bail
    if !fm.fileExists(atPath: sourcePath, isDirectory: &sourceIsdirectory) {
        reportErrorAndExit("Source \(sourcePath) cannot be found")
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
destPath = getFullPath(destPath)

// Check whether the destination is a directory or a file
if !fm.fileExists(atPath: destPath, isDirectory: &destIsdirectory) {
    // Destination is missing but this is valid if the destination is a file,
    // or an as-yet-uncreated directory, so check its extension before bailing
    if (destPath as NSString).pathExtension.count == 0 {
        // No file extension, ergo this is a directory
        processDirectory(destPath)

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
        processDirectory(destPath)
    }
}

// If the source is a directory and the target is a file, that's a mismatch
// we can't resolve, so warn and bail
if !destIsdirectory.boolValue {
    if sourceIsdirectory.boolValue {
        reportErrorAndExit("Source (dirctory) and destination (file) are mismatched")
    }

    // FROM 6.4.0
    // We can only accept a destination file if there's only one file on the list
    if sourceFiles.count > 1 {
        reportErrorAndExit("Source files require a directory destination")
    }
}

/*
 * DON'T DELETE SOURCE FILE(S) CHECKS
 */

// Auto-enable 'keep files' if the source and destination are the same
if sourcePath == destPath && (sourceFile == destFile || (sourceFile != "" && destFile == "")) {
    doDeleteSource = false
}

// FROM 6.4.0
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

// FROM 6.4.0
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
        writeToStderr("Source: \(sourcePath)/" + (sourceFile.count > 0 ? "\(sourceFile)" : ""))
    } else {
        writeToStderr("Sources: \(sourceFiles.count) \(sourceFiles.count == 1 ? "file" : "files")")
    }

    writeToStderr("Target: \(destPath)/" + (destFile.count > 0 ? "\(destFile)" : ""))
    if doChangeResolution { writeToStderr("New DPI: \(dpi)") }
    if doReformat { writeToStderr("New image format: \(newFormatForSips)") }
    if doDeleteSource { writeToStderr("Will delete source image(s)") }
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
            report("Source directory \(sourcePath) is empty")
            exit(EXIT_SUCCESS)
        }

        // Otherwise proceess each item - 'processFile()' determines suitability
        for file: String in contents.sorted() {
            // FROM 6.4.0 `processFile()` expects a full path
            processFile(sourcePath + "/" + file)
        }
    } catch {
        reportErrorAndExit("Unable to get contents of source directory \(sourcePath)")
    }
} else {
    // FROM 6.4.0
    // Run through source files added as arguments
    if sourceFiles.count > 0 {
        for file: String in sourceFiles {
            // FROM 6.4.0 `processFile()` expects a full path
            processFile(file)
        }
    }
}

/*
 * OUTCOME OUTPUT
 */

// Present a final task report, if requested
if doShowMessages {
    if fileCount == 1 {
        writeToStderr("1 file converted")
    } else if fileCount > 1 {
        writeToStderr("\(fileCount) files converted")
    } else {
        writeToStderr("No files converted")
    }
}

// Tidy up
if actions.count > 0 {
    actions.removeAllObjects()
}

// And done...
exit(EXIT_SUCCESS)
