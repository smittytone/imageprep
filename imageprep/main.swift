
//  main.swift
//  imageprep
//
//  Created by Tony Smith on 25/11/2020.

import Foundation
import Cocoa


// MARK: - Constants

let SUPPORTED_TYPES = ["png", "jpg", "jpeg", "tif", "tiff"]
let EMPTY_HEX_BYTES = "000000"


// MARK: - Global Variables

// File management values
let fm: FileManager = FileManager.default
var sourcePath: String = FileManager.default.currentDirectoryPath
var sourceFile: String = ""
var sourceIsdirectory: ObjCBool = false
var destPath: String = ""
var destFile: String = ""
var destIsdirectory: ObjCBool = false
var doOverwrite: Bool = false

// Image attributes and action flags
var padColour: String = "FFFFFF"
var cropHeight: Int = 2182
var cropWidth: Int = 1668
var padHeight: Int = 2192
var padWidth: Int = 1668
var scaleHeight = padHeight
var scaleWidth = padWidth
var dpi: Float = 150.0
var newFormatForSips: String = ""
var formatExtension: String = "png"
var doCrop: Bool = false
var doPad: Bool = false
var doReformat: Bool = false
var doScale: Bool = false
var doChangeResolution: Bool = false
var didChangeResolution: Bool = false
var doShowMessages: Bool = true
var doDeleteSource: Bool = true

// CLI argument management
var argValue: Int = 0
var argCount: Int = 0
var actionType: String = "c"
var prevArg: String = ""
var fileCount: Int = 0


// MARK: - Functions

func getFullPath(_ relativePath: String) -> String {

    // Convert a partial path to an absolute path

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


func processRelativePath(_ relativePath: String) -> String {

    // Add the basepath (the current working directory of the call) to the
    // supplied relative path - and then resolve it

    let absolutePath = fm.currentDirectoryPath + "/" + relativePath
    return (absolutePath as NSString).standardizingPath
}


func getFileSize(_ path: String) -> Int {

    // Report the size of the file at the specified absolute path.
    // Default to 0 for a missing file

    let data: Data = fm.contents(atPath: path) ?? Data.init(count: 0)
    return data.count
}


func processFile(_ file: String) {

    // Process a single source image file
    // NOTE 'file' contains a file name, not a path, so we need to add
    //      'sourcePath' to it when working at file level

    // Get the file extension
    let ext = (file.lowercased() as NSString).pathExtension

    // Only proceed if we have a file of the correct extension
    if !SUPPORTED_TYPES.contains(ext) { return }

    // Determine the file's output file path
    var outputFile = destPath + "/"
    if destIsdirectory.boolValue {
        // Target's a directory, so add the file name
        outputFile += file
    } else {
        // Destination is a specified file
        outputFile += destFile
    }

    // Get the full source image path
    let inputFile = "\(sourcePath)/\(file)"

    // Only proceed if the source image file is non-zero
    if getFileSize(inputFile) == 0 {
        report("File \(file) has no content -- skipping")
        return
    }

    // Report process
    report("Processing \(inputFile) as \(outputFile)...")

    // Set the temporary work file path
    let tmpFile = outputFile + ".sipstmp"

    // Make the temporary work file. It's a TIFF so we need to
    // check the source image type first
    if ext == "tif" || ext == "tiff" {
        // Source image IS a TIFF...
        if inputFile != outputFile {
            // ...but it's not at the same location as the output file,
            // so just copy it across
            do {
               try fm.copyItem(at: URL.init(fileURLWithPath: inputFile),
                               to: URL.init(fileURLWithPath: tmpFile))
            } catch {
                report("Error -- Could not write \(outputFile) -- skipping")
                return
            }
        }
    }  else {
        // The source is not a TIFF, so just create the temp file
        runSips([inputFile, "-s", "format", "tiff", "--out", tmpFile])
    }

    // First process actions on the temporary work file
    // Crop the file, if requested
    if doCrop {
        runSips([tmpFile, "-c", "\(cropHeight)", "\(cropWidth)", "--padColor", padColour])
    }

    // Pad the file, if requested
    if doPad {
        runSips([tmpFile, "-p", "\(padHeight)", "\(padWidth)", "--padColor", padColour])
    }

    // Scale the file, if requested
    if doScale {
        runSips([tmpFile, "-z", "\(scaleHeight)", "\(scaleWidth)", "--padColor", padColour])
    }

    // Set the DPI, if requested
    if doChangeResolution {
        runSips([tmpFile, "-s", "dpiHeight", "\(dpi)", "-s", "dpiWidth", "\(dpi)"])
    }

    // Set the image format, if requested
    if doReformat {
        // Whatever the image type, we output the new format
        // as a new file with the correct extension
        let newOutputFile = (outputFile as NSString).deletingPathExtension + "." + formatExtension

        if fm.fileExists(atPath: newOutputFile) && !doOverwrite {
            // Uh oh! There's already a file there and we have not set the 'do overwrite' flag
            report("Error -- target file \(newOutputFile) already exists -- skipping")
            return
        }

        // Create new-format file from the work file
        runSips([tmpFile, "-s", "format", newFormatForSips, "--out", newOutputFile])
    } else {
        // We're not reformatting the file, so write it back
        // using the source type (by its file extension)
        runSips([tmpFile, "-s", "format", processFormat(ext), "--out", outputFile])
    }

    // Remove the temporary work file now we're done
    let success = removeFile(tmpFile)
    if !success {
        report("Error -- Could not delete temporary file \(tmpFile) after processing")
    }

    // Remove the source file, if requested
    if doDeleteSource {
        let success = removeFile(inputFile)
        if !success {
            report("Error -- Could not delete source file \(inputFile) after processing")
        }
    }

    // Increment the file counter
    fileCount += 1
}


func removeFile(_ path: String) -> Bool {

    // Generic file remover called from 'processFile()'

    do { try fm.removeItem(at: URL.init(fileURLWithPath: path)) } catch { return false }
    return true
}


func runSips(_ args: [String]) {

    // Call sips using Process

    let task: Process = Process()
    task.executableURL = URL.init(fileURLWithPath: "/usr/bin/sips")
    if args.count > 0 { task.arguments = args }

    // Pipe out the output to avoid putting it in the log
    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = outputPipe

    do {
        try task.run()
    } catch {
        reportError("Cannot locate sips")
    }

    // Block until the task has completed (short tasks ONLY)
    task.waitUntilExit()

    if !task.isRunning {
        if (task.terminationStatus != 0) {
            // Command failed -- collect the output if there is any
            let outputHandle = outputPipe.fileHandleForReading
            var outString: String = ""
            if outputHandle.availableData.count > 0 {
                if let line = String(data: outputHandle.availableData, encoding: String.Encoding.utf8) {
                    outString = line
                }
            }

            if outString.count > 0 {
                print("Error -- sips reported an error: \(outString)")
            } else {
                print("Error -- sips reported error code \(task.terminationStatus) -- task not completed")
            }
        }
    }
}


func report(_ message: String) {

    // Generic message display routine

    if doShowMessages { print(message) }
}


func reportError(_ message: String, _ code: Int32 = 1) {

    // Generic error display routine

    print("Error -- " + message + " -- exiting")
    exit(code)
}


func processColour(_ colourString: String) -> String {

    // Take a colour value input, make sure it's hex and clean it up for sips

    var workColour = colourString

    // Remove any preceeding hex markers
    while true {
        var match: Bool = false

        for prefixString in ["#", "0x", "\\x", "x", "$"] {
            if (workColour as NSString).hasPrefix(prefixString) {
                workColour = String(workColour.suffix(workColour.count - prefixString.count))
                match = true
            }
        }

        if !match { break }
    }

    // Check for an out-of-range value
    if workColour.count > 6 {
        reportError("Invalid hex colour value supplied \(colourString)")
    }

    // Check it's actually hex (or makes sense as hex)
    let scanner = Scanner.init(string: workColour)
    var dummy: UInt32 = 0
    if !scanner.scanHexInt32(&dummy) {
        reportError("Invalid hex colour value supplied \(colourString)")
    }

    // Pre-pad the hex string up to six characters
    if workColour.count < 6 {
        workColour = String(EMPTY_HEX_BYTES.prefix(6 - workColour.count)) + workColour
    }

    return workColour
}


func processFormat(_ formatString: String) -> String {

    // Make sure a correct format has been passed, and adjust
    // if for sips use, eg. 'JPG' -> 'jpeg', 'tif' -> 'tiff'

    var workFormat = formatString.lowercased()
    var valid: Bool = false

    // Store the expected format as provided by the user --
    // this is later used to set the target's file extension
    formatExtension = formatString

    if workFormat == "jpg" {
        valid = true
        workFormat = "jpeg"
    } else if workFormat == "jpeg" {
        valid = true
    } else if workFormat == "tif" {
        valid = true
        workFormat = "tiff"
    } else if workFormat == "tiff" {
        valid = true
    } else if workFormat == "png" {
        valid = true
    }

    // If we don't have a good format, bail
    if !valid {
        reportError("Invalid image format selected: \(workFormat)")
    }

    return workFormat
}


func showHelp() {

    // Read in app version from info.plist

    showHeader()

    print("A macOS image preparation utility\n")
    print("Usage:\n    imageprep [-s path] [-d path] [-c pad_colour]")
    print("                      [-a s scale_height scale_width] ")
    print("                      [-a p pad_height pad_width]")
    print("                      [-a c crop_height crop_width] ")
    print("                      [-r] [-f] [-k] [-o] [-h]\n")
    print("    NOTE You can select either crop, pad or scale or all three, but actions will always")
    print("         be performed in this order: pad, then crop, then scale.\n")
    print("Options:")
    print("    -s / --source      [path]                  The path to an image or a directory of images.")
    print("                                               Default: current working directory.")
    print("    -d / --destination [path]                  The path to the images. Default: source directory.")
    print("    -a / --action      [type] [width] [height] The crop/pad dimensions. Type is s (scale), c (crop) or p (pad).")
    print("    -c / --colour      [colour]                The padding colour in Hex, eg. A1B2C3. Default: FFFFFF.")
    print("    -r / --resolution  [dpi]                   Set the image dpi, eg. 300.")
    print("    -f / --format      [format]                Set the image format: JPG/JPEG, PNG or TIF/TIFF.")
    print("    -o / --overwrite                           Overwrite an existing file. Without this, existing files will be kept.")
    print("    -k / --keep                                Keep the source file. Without this, the source will be deleted.")
    print("    -q / --quiet                               Silence output messages (errors excepted).")
    print("    -h / --help                                This help screen.\n")
}


func showVersion() {

    // Display the utility's version

    showHeader()

    print("\nCopyright 2020, Tony Smith (@smittytone). Source code available under the MIT licence.\n")
}


func showHeader() {

    // Display the utility's version number

    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    print("\nimageprep \(version) (\(build))")
}


// MARK: - Runtime Start

for argument in CommandLine.arguments {

    // Ignore the first comand line argument
    if argCount == 0 {
        argCount += 1
        continue
    }

    // Are we expecting a value? If so 'argValue' is not zero
    if argValue != 0 {
        // Make sure we have a value to read
        if argument.prefix(1) == "-" {
            reportError("Missing value for \(prevArg)")
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
                reportError("Invalid DPI value selected: 0.0")
            }
        case 5:
            newFormatForSips = processFormat(argument)
        case 6:
            actionType = argument
        case 7:
            // Set widths based on action and set the action flag if the value is good
            if actionType == "c" {
                cropWidth = Int(argument) ?? 0
                if cropWidth != 0 { doCrop = true }
            } else if actionType == "s" {
                scaleWidth = Int(argument) ?? 0
                if scaleWidth != 0 { doScale = true }
            } else {
                padWidth = Int(argument) ?? 0
                if padWidth != 0 { doPad = true }
            }
        case 8:
            // Set heights based on action, but clear the action flag if the value is bad
            if actionType == "c" {
                cropHeight = Int(argument) ?? 0
                if cropHeight == 0 { doCrop = false }
            } else if actionType == "s" {
                scaleHeight = Int(argument) ?? 0
                if scaleHeight == 0 { doScale = false }
            } else {
                padHeight = Int(argument) ?? 0
                if padHeight == 0 { doPad = false }
            }
        default:
            reportError("Unknown value: \(argument)")
        }

        if argValue > 5 && argValue < 8 {
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
        case "-h":
            fallthrough
        case "--help":
            showHelp()
            exit(0)
        case "--version":
            showVersion()
            exit(0)
        default:
            reportError("Unknown argument: \(argument)")
        }

        prevArg = argument
    }

    argCount += 1

    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argValue > 0 {
        reportError("Missing value for \(argument)")
    }
}

// Get the full source path
// NOTE It may point to a single file
sourcePath = getFullPath(sourcePath)

// Check whether the source is a directory or a file,
// and if neither exists, bail
if !fm.fileExists(atPath: sourcePath, isDirectory: &sourceIsdirectory) {
    reportError("Source \(sourcePath) cannot be found")
}

// If the source points to a file, get the components
if !sourceIsdirectory.boolValue {
    sourceFile = (sourcePath as NSString).lastPathComponent
    sourcePath = (sourcePath as NSString).deletingLastPathComponent
}

// Get full destination path
// NOTE It may point to a single file
destPath = getFullPath(destPath)

// Check whether the source is a directory or a file
if !fm.fileExists(atPath: destPath, isDirectory: &destIsdirectory) {
    // Destination is missing but this is valid if the destination is a file,
    // so check its extension before bailing
    if (destPath as NSString).pathExtension.count == 0 {
        // No file extension, ergo this is a directory, so bail
        reportError("Destination \(destPath) cannot be found")
    }
}

// If the destination points to a file, get the components
if !destIsdirectory.boolValue {
    // The source points to a file, so extract the file
    destFile = (destPath as NSString).lastPathComponent
    destPath = (destPath as NSString).deletingLastPathComponent

    // As a final check, test the path to the file -- we don't make
    // intermediate directories, yet
    if !fm.fileExists(atPath: destPath) {
        reportError("Destination directory \(destPath) cannot be found")
    }
}

// If the source is a directory and the target is a file, that's a mismatch
// we can't resolve, so warn and bail
if sourceIsdirectory.boolValue && !destIsdirectory.boolValue {
    reportError("Source (dirctory) and destination (file) are mismatched")
}

// Auto-enable 'keep files' if the source and destination are the same
if sourcePath == destPath && sourceFile == destFile {
    doDeleteSource = false
}

// Output the source and destination directories
if doShowMessages {
    print("Source: \(sourcePath)/" + (sourceFile.count > 0 ? "\(sourceFile)" : ""))
    print("Target: \(destPath)/" + (destFile.count > 0 ? "\(destFile)" : ""))
    if doChangeResolution { print("New DPI: \(dpi)") }
    if doReformat { print("New image format: \(newFormatForSips)") }
}

// Split the path for a single source file or source directory
if sourceIsdirectory.boolValue {
    // Source file is a directory, so enumerate its contents
    // and then process all the files, one by one
    if let fileEnumeration = fm.enumerator(atPath: sourcePath) {
        for file in fileEnumeration {
            processFile("\(file)")
        }
    }
} else {
    // The source file is a single image, so process it
    processFile(sourceFile)
}

// Present a final task report, if requested
if doShowMessages {
    if fileCount == 1 {
        print("1 file converted")
    } else if fileCount > 1 {
        print("\(fileCount) files converted")
    } else {
        print("No files converted")
    }
}
