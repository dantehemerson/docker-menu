import Cocoa

class StatusMenuController: NSObject {
    @IBOutlet weak var statusMenu: NSMenu!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let dockerApi = Docker()
    
    override func awakeFromNib() {
        let icon = NSImage(named: "DockerIcon")
        icon?.isTemplate = true
        
        statusItem.image = icon
        statusItem.menu = statusMenu
        
        let containers = dockerApi.getContainers()
        addMenuItems(containers)
        
        listenForDockerEvents()
    }
    
    func listenForDockerEvents() {
        let task = Process()
        task.launchPath = "/usr/local/bin/docker"
        task.arguments = ["events", "--format", "{{json .}}"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        let fileHandle = pipe.fileHandleForReading
        
        fileHandle.readabilityHandler = { fileHandle in
               guard let lineData = fileHandle.availableData.split(separator: UInt8(ascii: "\n")).first,
                     let line = String(data: lineData, encoding: .utf8) else { return }
               do {
                   let jsonData = try JSONSerialization.jsonObject(with: Data(line.utf8), options: []) as? [String: Any]
                   guard let action = jsonData?["Action"] as? String,
                         let type = jsonData?["Type"] as? String else { return }
                   
                   switch (type, action) {
                       case ("container", "start"),
                            ("container", "pause"),
                            ("container", "stop"),
                            ("container", "kill"),
                            ("container", "die"),
                            ("container", "destroy"):
                                debugPrint("Containers status updated, updading UI")
                                self.reloadAndShowItems()
                       default:
                           break
                   }
               } catch {
                   print("Error parsing JSON data from docker events: \(error)")
               }
           }
        
        task.launch()
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    @objc func reloadAndShowItems() {
        let containers = dockerApi.getContainers()
        removeAllImageItems()
        addMenuItems(containers)
    }
    
    @IBAction func stopAllClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.dockerApi.stopAllContainers()
        }
    }
    
    func removeAllImageItems() {
        let menuItems = statusItem.menu!.items
        debugPrint("menu items: ", menuItems)

        for item in menuItems {
            if(item.representedObject is DockerContainer) {
                debugPrint("Removing item from menu: " + item.description)
                statusItem.menu?.removeItem(item)
            }
        }
    }
    
    @IBAction func runAction(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let (action, container) = sender.representedObject as? (DockerAction, DockerContainer) {
                        self.dockerApi.runAction(action: action, containerName: container.name)
                    }
                  
                }
    }
  
    let statusImageNameByStatus: [DockerContainer.Status: String] = [
        .up: NSImage.statusAvailableName,
        .stopped: NSImage.statusUnavailableName,
        .paused: NSImage.statusPartiallyAvailableName
    ]
    
    func addMenuItems(_ containers: [DockerContainer]) {
        containers.forEach  { (container: DockerContainer) -> () in
            let containerMenuItem : NSMenuItem = NSMenuItem(title: "(\(container.status)) \(container.name)", action: nil, keyEquivalent: "")
            debugPrint("Adding menu item", containerMenuItem)
                
            let containerOptionsSubMenu = NSMenu()
            
            addContainerSubMenuOptions(container, containerOptionsSubMenu)
    
            
            containerMenuItem.submenu = containerOptionsSubMenu
            
            containerMenuItem.image = NSImage(named: statusImageNameByStatus[container.status] ??
                                              NSImage.statusUnavailableName)
            
            containerMenuItem.representedObject = container
            containerMenuItem.target = self

            statusItem.menu!.addItem(containerMenuItem)
        }
    }
    
    func addContainerSubMenuOptions(_ container: DockerContainer, _ parentMenu: NSMenu) {
        
        switch(container.status) {
        case .up:
            
            let openShellMenuItem = NSMenuItem(title: "Open Shell", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            openShellMenuItem.isEnabled = true
            openShellMenuItem.representedObject = (DockerAction.openShell, container)
            openShellMenuItem.target = self
            
            let restartMenuItem = NSMenuItem(title: "Restart", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            restartMenuItem.isEnabled = true
            restartMenuItem.representedObject = (DockerAction.restart, container)
            restartMenuItem.target = self
            
            let pauseMenuItem = NSMenuItem(title: "Pause", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            pauseMenuItem.isEnabled = true
            pauseMenuItem.representedObject = (DockerAction.pause, container)
            pauseMenuItem.target = self
            
            let stopMenuItem = NSMenuItem(title: "Stop", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            stopMenuItem.isEnabled = true
            stopMenuItem.representedObject = (DockerAction.stop, container)
            stopMenuItem.target = self
            
            let logsMenuItem = NSMenuItem(title: "Logs", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            logsMenuItem.isEnabled = true
            logsMenuItem.representedObject = (DockerAction.logs, container)
            logsMenuItem.target = self
            

            parentMenu.addItem(openShellMenuItem)
            parentMenu.addItem(restartMenuItem)
            parentMenu.addItem(pauseMenuItem)
            parentMenu.addItem(stopMenuItem)
            parentMenu.addItem(logsMenuItem)
            
            
            break
            
        case .paused:
            
            let unPauseMenuItem = NSMenuItem(title: "Unpause", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            unPauseMenuItem.isEnabled = true
            unPauseMenuItem.representedObject = (DockerAction.unpause, container)
            unPauseMenuItem.target = self
            

            parentMenu.addItem(unPauseMenuItem)
            
            break
        
        case .stopped:
            let startMenuItem = NSMenuItem(title: "Start", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            startMenuItem.isEnabled = true
            startMenuItem.representedObject = (DockerAction.start, container)
            startMenuItem.target = self
            
            let removeMenuItem = NSMenuItem(title: "Remove", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
            removeMenuItem.isEnabled = true
            removeMenuItem.representedObject = (DockerAction.remove, container)
            removeMenuItem.target = self
            

            parentMenu.addItem(startMenuItem)
            parentMenu.addItem(removeMenuItem)
            
            
            break
            
            
        }
    }
}
