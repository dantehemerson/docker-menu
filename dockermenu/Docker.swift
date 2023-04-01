//
//  Docker.swift
//  dockermenu
//
//  Created by Joel Carlbark on 2016-06-17.
//  Copyright © 2016 Joel Carlbark. All rights reserved.
//

import Foundation

class Docker {
    init() {
        setenv("PATH", "/usr/local/bin/", 1) // Needed by docker-machine, to know where VBoxManage is
        // TODO: Run this if docker toolbox is used, but not for Docker for Mac.
        // dockerEnv()
    }
    
    /* Parse output from "docker-machine env default" into something we can do setenv on.
        TODO: Make "default" configurable
    */
    func dockerEnv() {
        let task = Process()
        let pipe = Pipe()
        
        task.launchPath = "/usr/local/bin/docker-machine"
        task.arguments = ["env", "default"]
        task.standardOutput = pipe
        task.launch()
        
        let handle = pipe.fileHandleForReading
        let data = handle.readDataToEndOfFile()
        let result = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        let lines = result!.components(separatedBy: "\n")
        let exportLines = lines.filter {$0 != "" }.filter { (line:String) -> Bool in
            line.contains("export DOCKER")
        }
        
        let vars = exportLines.map { (line:String) -> EnvironmentVariable in
            let parts = line.components(separatedBy: " ")
            let env = parts[1].components(separatedBy: "=")
            return EnvironmentVariable(name: env[0],
                value: env[1].replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil))
        }
        
        vars.forEach{ (ev: EnvironmentVariable) -> () in
            debugPrint("Setting env: " + ev.name + "=" + ev.value)
            setenv(ev.name, ev.value, 1)
        }
    }
    
    func getContainers() -> [DockerContainer] {
        let task = Process()
        let pipe = Pipe()
        
        task.launchPath = "/usr/local/bin/docker"
        task.arguments = ["ps", "-a", "--format", "{{.Names}},{{.Status}}"]
        task.standardOutput = pipe
        task.launch()
        
        let handle = pipe.fileHandleForReading
        let data = handle.readDataToEndOfFile()
        
        let rawOutput = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        
        let result = (rawOutput! as String).trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .filter { !$0.isEmpty }
            .map { line -> DockerContainer in
                let values = line.split(separator: ",")
                let name = String(values[0])
                let status =  self.getContainerStatus(from: String(values[1]))
                return DockerContainer(name: name, status: status)
           }
                
        return result
    }
    
    func getContainerStatus(from statusMessage: String) -> DockerContainer.Status {
        if statusMessage.range(of: "Up") != nil {
            return .up
        } else if statusMessage.range(of: "Paused") != nil {
            return .paused
        } else {
            return .stopped
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
        
        let dockerPath = "/usr/local/bin/docker"
        
        switch action {
         case .start:
            return (dockerPath, ["start", containerName])
         case .remove:
             return (dockerPath, ["rm", containerName])
         case .openShell:
            debugPrint("TODO .openShell")
        
            return (dockerPath, [])
//             return ["exec", "-it", containerName, "/bin/bash;", "if [ $? -ne 0 ]; then exec -it", containerName, "/bin/sh; fi;"]
         case .logs:
            let commandArgs = ["-e", "tell application \"Terminal\" to do script \"docker logs -f \(containerName)\""]
            
            return ("/usr/bin/osascript" , commandArgs)
         case .restart:
             return (dockerPath,["restart", containerName])
         case .pause:
             return (dockerPath,["pause", containerName])
         case .stop:
             return (dockerPath,["stop", containerName])
         case .unpause:
             return (dockerPath, ["unpause", containerName])
         // TODO: Handle errors
         @unknown default:
             fatalError("Docker action not valid")
         }
    }
    
    
}
