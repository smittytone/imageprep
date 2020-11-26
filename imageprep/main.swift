
//  main.swift
//  imageprep
//
//  Created by Tony Smith on 25/11/2020.

import Foundation
import Cocoa



// MARK: - Global Variables

// File management values
let fm: FileManager = FileManager.default
var sourcePath: String = FileManager.default.currentDirectoryPath
var sourceFile: String = ""
var sourceIsdirectory: ObjCBool = false
var destPath: String = ""
var destFile: String = ""
var destIsdirectory: ObjCBool = false

// Image attributes and action flags
var padColour: String = "FFFFFF"
var cropHeight: Int = 2182
var cropWidth: Int = 1668
var padHeight: Int = 2192
var padWidth: Int = 1668
var scaleHeight = padHeight
var scaleWidth = padWidth
var dpi: Int = 300
var newFormat: String = ""
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

    // Report the file size
    // NOTE 'file' contains a file name, not a path, so we need to add
    //      'sourcePath' to it when working at file level

    let workPath = "\(sourcePath)/\(path)"
    let data: Data = fm.contents(atPath: workPath) ?? Data.init(count: 0)

    #if DEBUG
    print("\(workPath) size: \(data.count)")
    #endif

    return data.count
}


func processFile(_ file: String) {

    // Process a single source image file
    // NOTE 'file' contains a file name, not a path, so we need to add
    //      'sourcePath' to it when working at file level

    // Get the file extension to see if we're dealing with a valid image filethank
    let ext = (file.lowercased() as NSString).pathExtension

    // Only proceed if we have a file of the correct extension
    if ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "tif" || ext == "tiff" {
        // Determine this file's output file path
        var outFile = "\(destPath)"
        if destIsdirectory.boolValue {
            outFile += "/\(file)"
        } else {
            // Destination is a specified file
            outFile += "/\(destFile)"
        }

        #if DEBUG
        print("Output file: \(outFile)")
        #endif

        // Only proceed if the file is non-zero
        if getFileSize(file) == 0 {
            if doShowMessages {
                print("File \(file) has no content -- skipping")
            }
            return
        }

        let source = "\(sourcePath)/\(file)"

        // Copy the file before editing...
        if source != outFile {
            do {
                try fm.copyItem(at: URL.init(fileURLWithPath: source),
                                to: URL.init(fileURLWithPath: outFile))
            } catch {
                print("Could not write \(outFile) -- skipping")
                return
            }
        }

        // Report process
        if doShowMessages {
            print("Processing \(file) as \(outFile)...")
        }

        // We haven't (yet) altered the image's resolution
        didChangeResolution = false

        // Set the format (and perform the copy)
        if doReformat {
            // If we're converting from PNG or TIFF, perform a dpi change
            // BEFORE converting to the target format and mark as done
            if doChangeResolution {
                if ext == "png" || ext == "tif" || ext == "tiff" {
                    _ = runSips([outFile, "-s", "dpiHeight", "\(dpi)", "-s", "dpiWidth", "\(dpi)"])
                    didChangeResolution = true
                }
            }

            // Whatever the image type, output the new format as a new file
            let newOutFile = (outFile as NSString).deletingPathExtension + formatExtension

            #if DEBUG
            print("NEW FORMAT FILE: \(newOutFile)")
            #endif

            _ = runSips([outFile, "-s", "format", "\(newFormat)", "--out", newOutFile])

            // If we need to, delete the old source file
            if doDeleteSource && source != outFile {
                let success = removeFile(outFile)
                if !success && doShowMessages {
                    print("Error -- Could not delete \(outFile) after processing")
                }
            }

            // Set the work file to reference the new (format) file
            outFile = newOutFile
        }

        // Pad the file, as requested
        if doPad {
            _ = runSips([outFile, "-p", "\(padHeight)", "\(padWidth)", "--padColor", "\(padColour)"])
        }

        // Crop the file, as requested
        if doCrop {
            _ = runSips([outFile, "-c", "\(cropWidth)", "\(cropHeight)", "--padColor", "\(padColour)"])
        }

        // Scale the file, as requested
        if doScale {
            _ = runSips([outFile, "-z", "\(scaleHeight)", "\(scaleWidth)", "--padColor", "\(padColour)"])
        }

        // Set the DPI if we need to and have not done so yet (see above)
        if doChangeResolution && !didChangeResolution {
            if ext == "jpg" || ext == "jpeg" {
                // sips does not apply dpi settings to JPEGs (why???) so if the target image is a JPEG,
                // convert it to PNG, apply the dpi settings and then convert it back again.
                let tmpFile = outFile + "-sipstmp"
                _ = runSips([outFile, "-s", "format", "png", "--out", tmpFile])
                _ = runSips([tmpFile, "-s", "dpiHeight", "\(dpi)", "-s", "dpiWidth", "\(dpi)"])
                _ = runSips([tmpFile, "-s", "format", "jpeg", "--out", outFile])

                let success = removeFile(tmpFile)
                if !success && doShowMessages {
                    print("Error -- Could not delete temporary file \(tmpFile) after processing")
                }
            } else {
                // For all other image types, just do the DPI change
                _ = runSips([outFile, "-s", "dpiHeight", "\(dpi)", "-s", "dpiWidth", "\(dpi)"])
            }
        }

        // Increment the file counter
        fileCount += 1

        // Remove the source file if requested
        if doDeleteSource {
            let success = removeFile(source)
            if !success && doShowMessages {
                print("Error -- HelloCould not delete \(source) after processing")
            }
        }
    }
}


func removeFile(_ path: String) -> Bool {

    // Generic file remover

    do {
        try fm.removeItem(at: URL.init(fileURLWithPath: path))
    } catch {
        return false
    }

    return true
}


func runSips(_ args: [String]) -> Bool {

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
        print("[ERROR] Cannot locate sips")
        return false
    }

    // Block until the task has completed (short tasks ONLY)
    task.waitUntilExit()

    if !task.isRunning {
        if (task.terminationStatus != 0) {
            // Command failed -- collect the output if there is any
            // DOES THIS EVEN WORK?
            let outputHandle = outputPipe.fileHandleForReading
            var outString: String = ""
            if outputHandle.availableData.count > 0 {
                if let line = String(data: outputHandle.availableData, encoding: String.Encoding.utf8) {
                    outString = line
                }
            }

            if outString.count > 0 {
                print("[ERROR] sips reported an error: \(outString)")
            } else {
                print("[ERROR] sips exited with code \(task.terminationStatus)")
            }
        }
    }

    return true
}


func processColour(_ colourString: String) -> String {

    // Take a hex colour and remove any preceeding characters

    var workColour = colourString
    while true {
        var match: Bool = false

        for prefixString in ["#", "0x", "\\x", "x"] {
            if (workColour as NSString).hasPrefix(prefixString) {
                workColour = String(workColour.suffix(workColour.count - prefixString.count))
                match = true
            }
        }

        if !match {
            break
        }
    }

    return workColour
}


func processFormat(_ formatString: String) -> String {

    // Make sure a correct format has been passed, and adjust
    // if for sips use, eg. 'JPG' -> 'jpeg', 'tif' -> 'tiff'

    var workFormat = formatString.lowercased()
    var valid: Bool = false
    formatExtension = workFormat

    if workFormat == "jpg" {
        valid = true
        workFormat = "jpeg"
    } else if workFormat == "jpeg" {
        valid = true
    } else if workFormat == "tif" {
        valid = true
        workFormat = "tiff"
        formatExtension = "tiff"
    } else if workFormat == "tiff" {
        valid = true
    } else if workFormat == "png" {
        valid = true
    }

    // If we don't have a good format, bail
    if !valid {
        print("Invalid image format selected: \(workFormat) -- exiting")
        exit(1)
    }

    return workFormat
}


func showHelp() {

    // Read in app version from info.plist

    showHeader()
    print("A macOS image preparation utility\n")
    print("Usage:\n    imageprep [-s path] [-d path] [-c padColour]")
    print("                      [-a s scale_height scale_width] ")
    print("                      [-a p pad_height pad_width]")
    print("                      [-a c crop_height crop_width] ")
    print("                      [-r] [-f] [-k] [-h]\n")
    print("    NOTE You can select either crop, pad or scale or all three, but actions will always")
    print("         be performed in this order: pad, then crop, then scale.\n")
    print("Options:")
    print("    -s / --source      [path]                  The path to an image or a directory of images. Default: current working directory.")
    print("    -d / --destination [path]                  The path to the images. Default: source directory.")
    print("    -a / --action      [type] [width] [height] The crop/pad dimensions. Type is s (scale), c (crop) or p (pad).")
    print("    -c / --colour      [colour]                The padding colour in Hex, eg. A1B2C3. Default: FFFFFF.")
    print("    -r / --resolution  [dpi]                   Set the image dpi, eg. 300")
    print("    -f / --format      [format]                Set the image format: JPG/JPEG, PNG or TIF/TIFF")
    print("    -k / --keep                                Keep the source file. Without this, the source will be deleted.")
    print("    -q / --quiet                               Silence output messages (errors excepted).")
    print("    -h / --help                                This help screen.")
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

    if argCount == 0 {
        argCount += 1
        continue
    }

    if argValue != 0 {
        // Make sure we're not reading in an option rather than a value
        if argument.prefix(1) == "-" {
            print("[ERROR] Missing value for \(prevArg)")
            exit(1)
        }

        switch argValue {
        case 1:
            sourcePath = argument
        case 2:
            destPath = argument
        case 3:
            padColour = processColour(argument)
        case 4:
            dpi = Int(argument) ?? 300
        case 5:
            newFormat = processFormat(argument)
        case 6:
            actionType = argument
        case 7:
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
            print("[ERROR] Unknown argument: \(argument)")
            exit(1)
        }

        if argValue > 5 && argValue < 8 {
            argValue += 1
        } else {
            argValue = 0
        }
    } else {
        switch argument {
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
        case "-f":
            fallthrough
        case "--format":
            doReformat = true
            argValue = 5
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
        case "-h":
            fallthrough
        case "--help":
            showHelp()
            exit(0)
        case "--version":
            showVersion()
            exit(0)
        default:
            print("[ERROR] Unknown argument: \(argument)")
            exit(1)
        }

        prevArg = argument
    }

    argCount += 1

    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argValue > 0 {
        print("[ERROR] Missing value for \(argument)")
        exit(1)
    }
}

print("CROP width: \(cropWidth), height: \(cropHeight)")

// Get the full source path
// NOTE At this point they may be single filenames
sourcePath = getFullPath(sourcePath)

// Check that the source is a directory or a file
// If neither exists, we have to bail
if !fm.fileExists(atPath: sourcePath, isDirectory: &sourceIsdirectory) {
    print("Source \(sourcePath) cannot be found -- exiting")
    exit(1)
}

// Do we have a source file or a source directory
if !sourceIsdirectory.boolValue {
    // The source points to a file, so extract the file
    sourceFile = (sourcePath as NSString).lastPathComponent
    sourcePath = (sourcePath as NSString).deletingLastPathComponent
}

#if DEBUG
print("S DIR: \(sourcePath)")
print("S FIL: \(sourceFile)")
#endif

// Get full destination path
// NOTE At this point it may be a single filename
destPath = getFullPath(destPath)

if !fm.fileExists(atPath: destPath, isDirectory: &destIsdirectory) {
    // Destination is missing -- this is valid if the destination is a file,
    // so check its extension
    let ext = (destPath as NSString).pathExtension
    if ext.count == 0 {
        // No file extension, ergo this is a directory
        print("Destination \(destPath) cannot be found -- exiting")
        exit(1)
    }
}

// Do we have a destination file or a destination directory
if !destIsdirectory.boolValue {
    // The source points to a file, so extract the file
    destFile = (destPath as NSString).lastPathComponent
    destPath = (destPath as NSString).deletingLastPathComponent
}

#if DEBUG
print("D DIR: \(destPath)")
print("D FIL: \(destFile)")
#endif

// If the source is a directory and the target is a file, that's a mismatch
// we can't resolve, so warn and bail
if sourceIsdirectory.boolValue && !destIsdirectory.boolValue {
    print("Source (dirctory) and destination (file) are mismatched -- exiting")
    exit(1)
}

// Auto-enable 'keep files' if the source and destination are the same
if sourcePath == destPath && sourceFile == destFile {
    doDeleteSource = false
}

// Output the source and destination directories
if doShowMessages {
    print("Source: \(sourcePath)" + (sourceFile.count > 0 ? "/\(sourceFile)" : ""))
    print("Target: \(destPath)" + (destFile.count > 0 ? "/\(destFile)" : ""))
    if doChangeResolution {
        print("New DPI: \(dpi)")
    }
}

// Split for a single source file or source directory
if sourceIsdirectory.boolValue {
    // Source file is a directory, so enumerate its contents
    // and then process each one, one by one
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
