import Foundation

private let usableStates = ["restarting", "running", "paused", "created", "exited"]

struct DockerContainer {
    let id: String

    let name: String

    // status, managed by app. Not related to docker container status
    let status: Status

    // original state coming from docker
    let state: String

    // Flag used to indicate if it must be showed, or remove from the menu
    func isUnusableForApp() -> Bool {
        return !usableStates.contains(state)
    }
    
    func isDestroyed() -> Bool {
        return state == "destroy"
    }
    
    func getTitle() -> String {
        return "\(self.name)"
    }

    enum Status {
        case running
        case paused
        case stopped
        case unknown
    }
}
