import Foundation

class Docker {
    let dockerPath = "/usr/local/bin/docker"
    
    
    func getContainers() -> [DockerContainer] {
        let task = Process()
        let pipe = Pipe()
        
        task.launchPath = dockerPath
        task.arguments = ["ps", "-a", "--format", "{{.ID}},{{.Names}},{{.State}}"]
        task.standardOutput = pipe
        task.launch()
        
        let handle = pipe.fileHandleForReading
        let data = handle.readDataToEndOfFile()
        
        let rawOutput = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        
        let containers = (rawOutput! as String).trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .filter { !$0.isEmpty }
            .map { line -> DockerContainer? in
                let values = line.split(separator: ",")
                let id = String(values[0])
                let name = String(values[1])
                let state = String(values[2])
                
                let status =  self.getContainerStatusFromState(from: state)
                
                // Skip unsupported containers
                if (status == nil) {
                    return nil
                }
                                    
                return DockerContainer(id: id,name: name, status: status!)
            }.compactMap { $0 }
                
        return containers
    }
    
    func getContainerStatusFromState(from containerState: String) -> DockerContainer.Status? {
        switch containerState {
            case "restarting", "running":
                return .running
            case "paused":
                return .paused
            case "created", "exited":
                return .stopped
            // Ignore containers with status (dead, removing).
            default:
                return nil
        }
    }

    func stopAllContainers() {
        debugPrint("Stopping all containers")
        let containers = self.getContainers()
        containers.forEach  { (container: DockerContainer) -> () in
            runAction(action: DockerAction.stop, containerName: container.name)
        }
    }
    
    func runAction(action: DockerAction, containerName: String) {
        let (program, args) = getActionCommand(action, containerName)
        
        let task = Process()
        task.launchPath = program
        task.arguments = args
        task.launch()
        task.waitUntilExit()
    }
    
    private func getActionCommand(_ action: DockerAction, _ containerName: String) -> (String, [String]) {
        switch action {
             case .start:
                return (self.dockerPath, ["start", containerName])
             case .remove:
                return (self.dockerPath, ["rm", containerName])
             case .openShell:
                let dockerShellCommand = "docker exec -it \(containerName) /bin/bash; if [ $? -ne 0 ]; then docker exec -it \(containerName) /bin/sh; fi;"
                let commandArgs = ["-e", "tell application \"Terminal\" to do script \"\(dockerShellCommand)\""]
                
                return ("/usr/bin/osascript", commandArgs)
             case .logs:
                let commandArgs = ["-e", "tell application \"Terminal\" to do script \"docker logs -f \(containerName)\""]
                
                return ("/usr/bin/osascript" , commandArgs)
             case .restart:
                return (self.dockerPath,["restart", containerName])
             case .pause:
                return (self.dockerPath,["pause", containerName])
             case .stop:
                return (self.dockerPath,["stop", containerName])
             case .unpause:
                return (self.dockerPath, ["unpause", containerName])
         }
    }
}
