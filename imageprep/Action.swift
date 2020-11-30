
//  imageprep
//
//  Created by Tony Smith on 30/11/2020.


import Foundation
import Cocoa



class Action {

    var type: String = ""
    var width: Int = -1
    var height: Int = -1
    var colour: String = "FFFFFF"

    init(_ type: String = "", _ width: Int = -1, _ height: Int = -1, _ colour: String = "FFFFFF") {
        self.type = type
        self.width = width
        self.height = height
        self.colour = colour
    }
}
