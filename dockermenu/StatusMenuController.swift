import Cocoa

@available(macOS 10.12.2, *)
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
        task.arguments = [
            "events",
            "--filter", "type=container",
            "--filter", "event=create",
            "--filter", "event=start",
            "--filter", "event=stop",
//            "--filter", "event=kill",
            "--filter", "event=pause",
            "--filter", "event=unpause",
            "--filter", "event=delete",
//            "--filter", "event=destroy",
            "--filter", "event=restart",
//            "--filter", "event=die",
            // 12 character id format
            "--format", "{{if gt (len .ID) 12}}{{slice .ID 0 12}}{{else}}{{.ID}}{{end}}"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        let fileHandle = pipe.fileHandleForReading
        
        fileHandle.readabilityHandler = { fileHandle in
               guard let lineData = fileHandle.availableData.split(separator: UInt8(ascii: "\n")).first,
                     let containerId = String(data: lineData, encoding: .utf8) else { return }
              
                if (!containerId.isEmpty) {
                    debugPrint("Container status updated. ContainerID: \(containerId)")

                    do {
                        let container = try self.dockerApi.getContainerById(containerId)
                        
                        self.updateContainerMenuItem(container)
                    } catch DockerError.containerNotFound {
                        debugPrint("Error updating container menu item. Container \(containerId) not found")
                    } catch {
                        debugPrint("Error updating container menu item")
                    }
                }
           }
        
        task.launch()
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    func updateContainerMenuItem(_ container: DockerContainer) {
        debugPrint("Updating container menu item", container)
         
        let menuItem = statusItem.menu!.items.first { item in
            if let dockerContainer = item.representedObject as? DockerContainer {
                return dockerContainer.id == container.id
            } else {
                return false
            }
        }

        if (menuItem != nil) {
            menuItem!.title =  "(\(container.status)) \(container.name)"
            menuItem!.image = NSImage(named: statusImageNameByStatus[container.status] ??
                                NSImage.statusUnavailableName)

            // Load submenu options that matches new container status
            if((menuItem!.submenu) != nil) {
                menuItem!.submenu!.removeAllItems()
                addContainerSubMenuOptions(container, menuItem!.submenu!)
            }
        }
    }
    
    @IBAction func stopAllClicked(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.dockerApi.stopAllContainers()
        }
    }

    @IBAction func runAction(_ sender: NSMenuItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let (action, container) = sender.representedObject as? (DockerAction, DockerContainer) {
                self.dockerApi.runAction(action: action, containerName: container.name)
            }
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
  
    let statusImageNameByStatus: [DockerContainer.Status: String] = [
        .running: NSImage.statusAvailableName,
        .stopped: NSImage.statusNoneName,
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
            case .running:
                
                let openShellMenuItem = NSMenuItem(title: "Open Shell", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                openShellMenuItem.image = NSImage(named: NSImage.rightFacingTriangleTemplateName)
                openShellMenuItem.isEnabled = true
                openShellMenuItem.representedObject = (DockerAction.openShell, container)
                openShellMenuItem.target = self
                
                let restartMenuItem = NSMenuItem(title: "Restart", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                restartMenuItem.image = NSImage(named: NSImage.refreshTemplateName)
                restartMenuItem.isEnabled = true
                restartMenuItem.representedObject = (DockerAction.restart, container)
                restartMenuItem.target = self

                let pauseMenuItem = NSMenuItem(title: "Pause", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                pauseMenuItem.image = NSImage(named: NSImage.touchBarPauseTemplateName)
                pauseMenuItem.isEnabled = true
                pauseMenuItem.representedObject = (DockerAction.pause, container)
                pauseMenuItem.target = self
                
                let stopMenuItem = NSMenuItem(title: "Stop", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                stopMenuItem.image = NSImage(named: NSImage.touchBarRecordStopTemplateName)
                stopMenuItem.isEnabled = true
                stopMenuItem.representedObject = (DockerAction.stop, container)
                stopMenuItem.target = self
                
                let logsMenuItem = NSMenuItem(title: "Logs", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                logsMenuItem.image = NSImage(named: NSImage.touchBarTextLeftAlignTemplateName)
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
                let unPauseMenuItem = NSMenuItem(title: "UnPause", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                unPauseMenuItem.image = NSImage(named: NSImage.touchBarPlayTemplateName)
                unPauseMenuItem.isEnabled = true
                unPauseMenuItem.representedObject = (DockerAction.unpause, container)
                unPauseMenuItem.target = self
                

                parentMenu.addItem(unPauseMenuItem)
                
                break
            
            case .stopped:
                let startMenuItem = NSMenuItem(title: "Start", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                startMenuItem.image = NSImage(named: NSImage.touchBarPlayTemplateName)
                startMenuItem.isEnabled = true
                startMenuItem.representedObject = (DockerAction.start, container)
                startMenuItem.target = self
                
                let removeMenuItem = NSMenuItem(title: "Remove", action: #selector(StatusMenuController.runAction(_:)), keyEquivalent: "")
                removeMenuItem.image = NSImage(named: NSImage.touchBarDeleteTemplateName)
                removeMenuItem.isEnabled = true
                removeMenuItem.representedObject = (DockerAction.remove, container)
                removeMenuItem.target = self
                

                parentMenu.addItem(startMenuItem)
                parentMenu.addItem(removeMenuItem)
                
                break
        }
    }
}
