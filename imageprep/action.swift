/*
    imageprep
    action.swift

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


/*
    A simple class to hold image processing actions.
    These will be held in an array by the main program.

    'type' -- the action to be performed:
              -c -- crop
              -p -- pad
              -z -- scale
    'width' -- the width of the image after the action
    'height' -- the height of the image after the action
    'colour' -- the current pad colour (ignored on scale actions)
 */
final class Action {

    // MARK: - Properties
    var type: String = ""
    var width: Int = -1
    var height: Int = -1
    var colour: String = "FFFFFF"


    // MARK: - Lifecycle Functions
    init(_ type: String = "",
         _ width: Int = -1,
         _ height: Int = -1,
         _ colour: String = "FFFFFF") {

        self.type = type
        self.width = width
        self.height = height
        self.colour = colour
    }

}
