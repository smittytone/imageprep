/*
    imageprep
    imageprep.swift

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
import Clicore


struct Imageprep {

    /**
     Load the specified image and gather data from it.

     - Parameters:
        - path: An image file path.

     - Returns: An ImageInfo object, or `nil` on error.
     */
    static func getImageInfo(_ path: String) -> ImageInfo? {

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
    static func processDirectory(_ path: String) {

        if doMakeSubDirectories {
            // Try to create the path to the specified directory
            do {
                try fm.createDirectory(at: URL.init(fileURLWithPath: path),
                                       withIntermediateDirectories: true,
                                       attributes: nil)
            } catch {
                Stdio.reportErrorAndExit("Destination \(path) does not exist and cannot be created")
            }
        } else {
            // Directory doesn't exist, we've not been told to create it, so bail
            Stdio.reportErrorAndExit("Destination \(destPath) cannot be found")
        }
    }


    /**
     Process a single source-image file.

     FROM 7.0.0 `file` is a full path including a file name

     - Parameters:
        - file: An image file path.
     */
    static func processFile(_ file: String) {

        // Get the file extension
        let ext: String = (file.lowercased() as NSString).pathExtension
        // FROM 7.0.0
        let fileName = (file as NSString).lastPathComponent

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

        // Check the source image by loading it and getting image info
        let imageInfo: ImageInfo? = getImageInfo(file)
        if imageInfo == nil {
            Stdio.reportWarning("File \(fileName) has no content -- skipping")
            return
        }

        if justInfo {
            // User just wants file data, so output it and exit
            let hasAlpha: String = imageInfo!.hasAlpha ? "alpha" : "no-alpha"
            Stdio.output("\(file) \(imageInfo!.width) \(imageInfo!.height) \(imageInfo!.dpi) \(imageInfo!.aspectRatio) " + hasAlpha)
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
                    Stdio.reportWarning("Could not write \(outputFile) -- skipping")
                    return
                }
            }
        }  else {
            // The source is not a TIFF, so just create the temp file
            runSips([file, "-s", "format", "tiff", "--out", tmpFile])
        }

        // First process actions on the temporary work file
        var sipsArgs: [String]
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
                sipsArgs = [tmpFile, action.type, "\(height)", "\(width)"]

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
                            // Deal with sips zero offset issue with a static function
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
                Stdio.reportWarning("target file \(newOutputFile) already exists -- skipping")
                return
            }

            // FROM 7.0.0
            // Apply JPEG compression level
            sipsArgs = [tmpFile, "--out", newOutputFile, "-s", "format", newFormatForSips]
            if newFormatForSips == "jpeg" {
                sipsArgs.append(contentsOf: ["-s", "formatOptions", "\(jpegCompression)"])
            }

            // Create new-format file from the work file
            runSips(sipsArgs)
            outputFile = newOutputFile
        } else {
            // We're not reformatting the file, so write it back
            // using the source type (by its file extension)
            sipsArgs = [tmpFile, "--out", outputFile, "-s", "format", processFormat(ext)]
            if formatExtension == "jpeg" {
                sipsArgs.append(contentsOf: ["-s", "formatOptions", "\(jpegCompression)"])
            }

            runSips(sipsArgs)
        }

        // Remove the temporary work file now we're done
        let success: Bool = removeFile(tmpFile)
        if !success {
            Stdio.reportWarning("Could not delete temporary file \(tmpFile) after processing")
        }

        // Remove the source file, if requested
        if doDeleteSource {
            let success: Bool = removeFile(file)
            if !success {
                Stdio.reportWarning("Could not delete source file \(fileName) after processing")
            }
        }

        // Increment the file counter
        fileCount += 1

        // Report process
        Stdio.report("Image \(file) processed to \(outputFile)...")
    }


    /**
     Generic file remover called from `processFile()`.

     - Parameters:
        - path: An image file path.

     - Returns: `true` if the operation succeeded, otherwise `false`.
     */
    static func removeFile(_ path: String) -> Bool {

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
    static func runSips(_ args: [String]) {

        let (code, text) = runProcess(app: "/usr/bin/sips", with: args)
        if code != 0 {
            Stdio.reportError("sips reported an error: \(text)")
        }

        /*
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
            Stdio.reportErrorAndExit("Cannot locate sips")
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
                    Stdio.reportError("sips reported an error: \(outString)")
                } else {
                    Stdio.reportError("sips reported error code \(task.terminationStatus) -- task not completed")
                }
            }
        }
         */
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
    static func sipsOffsetfix(_ offsetValue: Int) -> Float {

        if offsetValue == 0 {
            return 0.0001
        }

        return Float(offsetValue)
    }


    /**
     Validate a user-supplied colour value.

     Check that the value is in hex, and clean it up for `sips`.

     - Parameters:
        - colourString: The colour value as a String.

     - Returns: The corrected colour value as a String.
     */
    static func processColour(_ colourString: String) -> String {

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
            Stdio.reportErrorAndExit("Invalid hex colour value supplied \(colourString)")
        }

        // Check it's actually hex (or makes sense as hex)
        let scanner: Scanner = Scanner.init(string: workColour)
        var dummy: UInt64 = 0
        if !scanner.scanHexInt64(&dummy) {
            Stdio.reportErrorAndExit("Invalid hex colour value supplied \(colourString)")
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
    static func processFormat(_ format: String) -> String {

        // Store the expected format as provided by the user --
        // this is later used to set the target's file extension
        formatExtension = format
        var workFormat: String = format.lowercased()

        // If we don't have a good format, bail
        if !SUPPORTED_TYPES.contains(workFormat) {
            Stdio.reportErrorAndExit("Invalid image format selected: \(workFormat)")
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
    static func processActionType(_ arg: String) -> String {

        let workArg: String = arg.lowercased()

        if !ACTION_TYPES.contains(workArg) {
            Stdio.reportErrorAndExit("Invalid action selected: \(arg)")
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
    static func processActionValue(_ arg: String, _ action: String, _ isWidth: Bool) -> Int {

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
            Stdio.reportErrorAndExit("Invalid \(theAction) \(theValue) value")
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
    static func addAction(_ action: String, _ width: Int, _ height: Int) {

        if (width == USE_IMAGE && height == USE_IMAGE) || (width == SCALE_TO_HEIGHT && height == SCALE_TO_WIDTH) {
            let theAction: String = getActionName(action)
            Stdio.reportWarning("Action \(theAction) will not change the image -- ignoring")
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
    static func getActionName(_ action: String) -> String {

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
    static func processCropFix(_ arg: String) -> Int {

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
            Stdio.reportErrorAndExit("Invalid crop anchor point: \(arg)")
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
    static func processCropOffset(_ arg: String) -> Int {

        let workArg: String = arg.lowercased()
        let value: Int = Int(workArg) ?? -99
        if value < 0 {
            Stdio.reportErrorAndExit("Invalid crop offset: \(arg)")
        }

        return value
    }


    /**
     Validate a user-specified JPEG compression level expressed as a percentage
     (with or without the % symbol).

     The app will exit on an invalid value.

     FROM 7.0.0

     - Parameters:
        - arg: The anchor offset CLI argument.

     - Returns: The compression level offset as a float.
     */
    static func processCompressionLevel(_ arg: String) -> Double {

        var workArg: String = arg.lowercased()
        if let percentPosition = workArg.firstIndex(of: "%") {
            workArg = String(workArg[..<percentPosition])
        }

        let value: Double = Double(workArg) ?? -1.0
        if value <= 0 || value > 100.0 {
            Stdio.reportErrorAndExit("Invalid JPEG compression level: \(arg)%")
        }

        return value
    }
}
