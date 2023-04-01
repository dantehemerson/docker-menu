//
//  DockerContainer.swift
//  dockermenu
//
//  Created by Dante Hemerson Calderon Vasquez on 19/03/23.
//  Copyright © 2023 Joel Carlbark. All rights reserved.
//

import Foundation

struct DockerContainer {
    var name: String
    var status: Status

    enum Status {
        case up
        case paused
        case stopped
    }
}
