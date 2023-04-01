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
