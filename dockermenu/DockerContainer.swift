import Foundation

struct DockerContainer {
    var name: String
    var status: Status

    enum Status {
        case running
        case paused
        case stopped
    }
}
