import Foundation

struct DockerContainer {
    let id: String
    let name: String
    let status: Status

    enum Status {
        case running
        case paused
        case stopped
    }
}
