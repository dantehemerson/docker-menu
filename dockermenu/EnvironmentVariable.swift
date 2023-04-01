//
//  EnvironmentVariable.swift
//  dockermenu
//
//  Created by Joel Carlbark on 2016-06-18.
//  Copyright © 2016 Joel Carlbark. All rights reserved.
//

import Foundation

struct EnvironmentVariable {
    var name: String
    var value: String
}

enum DockerAction {
    case start
    case restart
    case pause
    case unpause
    case stop
    case logs
    case openShell
    case remove
}
