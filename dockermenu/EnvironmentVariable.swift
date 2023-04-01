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
