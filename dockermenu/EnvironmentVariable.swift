import Foundation

struct EnvironmentVariable {
    var name: String
    var value: String
}

enum DockerAction {
    case start // Start the container
    case restart // Restart the container
    case pause // Pause the container
    case unpause // UnPause the container
    case stop // Stop the container
    case logs // Open the Terminal and show the logs of the container
    case openShell // Open the Terminal and show the interactive shell(bash or sh).
    case remove // Deletes the container
}
