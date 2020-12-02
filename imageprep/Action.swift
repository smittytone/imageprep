
/*
 *
 * imageprep
 *
 * Created by Tony Smith on 30/11/2020.
 *
 */
import Foundation
import Cocoa


/*
 *
 * A simple class to hold image processing actions.
 * These will be held in an array by the main program.
 *
 * 'type' -- the action to be performed:
 *           -c -- crop
 *           -p -- pad
 *           -z -- scale
 * 'width' -- the width of the image after the action
 * 'height' -- the height of the image after the action
 * 'colour' -- the current pad colour (ignored on scale actions)
 *
 */
class Action {

    var type: String = ""
    var width: Int = -1
    var height: Int = -1
    var colour: String = "FFFFFF"

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
