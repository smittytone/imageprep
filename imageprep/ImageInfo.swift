/*
    imageprep
    image.swift

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


/*
    A simple class to hold image information:

    'width' -- the width of the image after the action
    'height' -- the height of the image after the action
    'dpi' -- the resolution of the image
    'hasAlpha' -- whether the image has an alpha channel
 */
final class ImageInfo {

    // MARK: - Constants

    let BASE_DPI = 72.0


    // MARK: - Properties

    var width: Int = -1
    var height: Int = -1
    var dpi: CGFloat = -1
    var hasAlpha: Bool = false
    var aspectRatio: CGFloat = 1.0


    // MARK: - Lifecycle Functions

    init(_ data: Data) {
        if let theImageRep: NSBitmapImageRep = NSBitmapImageRep(data: data) {
            // Set the instance
            self.width = theImageRep.pixelsWide
            self.height = theImageRep.pixelsHigh
            calculateAspectRatio()

            // Calculate the image DPI
            self.dpi = CGFloat(theImageRep.pixelsWide) * CGFloat(BASE_DPI) / theImageRep.size.width
            self.hasAlpha = theImageRep.hasAlpha
        }
    }


    // MARK: - Misc Functions

    private func calculateAspectRatio() {

        self.aspectRatio = CGFloat(self.width) / CGFloat(self.height)
    }
}
