/**
The MIT License (MIT)

Copyright (c) 2015 Yohei Yoshihara

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import Cocoa

enum ItemState: Int {
  case disconnected = 0
  case connectingNoSelection = 1
  case connectingOneSelection = 2
  case connectingMultipleSelection = 3
}

let connectItemStates = [true, false, false, false]
let disconnectItemStates = [false, true, true, true]
let makeFolderItemStates = [false, true, true, true]
let renameFileItemStates = [false, false, true, false]
let changePermissionsItemStates = [false, false, true, false]
let deleteFileItemStates = [false, false, true, false]
let downloadItemStates = [false, false, true, true]
let uploadItemStates = [false, true, true, true]
let refreshItemStates = [false, true, true, true]


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet weak var fileMenu: NSMenu!
  @IBOutlet weak var newConnectionMenu: NSMenuItem!
  @IBOutlet weak var disconnectMenu: NSMenuItem!
  
  @IBOutlet weak var operationMenu: NSMenu!
  @IBOutlet weak var downloadMenu: NSMenuItem!
  @IBOutlet weak var uploadMenu: NSMenuItem!
  @IBOutlet weak var makeFolderMenu: NSMenuItem!
  @IBOutlet weak var renameFileMenu: NSMenuItem!
  @IBOutlet weak var changePermissionsMenu: NSMenuItem!
  @IBOutlet weak var refreshMenu: NSMenuItem!
  @IBOutlet weak var deleteFileMenu: NSMenuItem!

  var state = ItemState.disconnected

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(AppDelegate.didConnect(_:)), name: NSNotification.Name(rawValue: DidConnectNotification), object: nil)
    nc.addObserver(self, selector: #selector(AppDelegate.didDisconnect(_:)), name: NSNotification.Name(rawValue: DidDisconnectNotification), object: nil)
    nc.addObserver(self, selector: #selector(AppDelegate.fileListSelectionChanged(_:)), name: NSNotification.Name(rawValue: FileListSelectionChangedNotification), object: nil)
    
    fileMenu.autoenablesItems = false
    operationMenu.autoenablesItems = false
    updateMenuStates()
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
  }
  
  func updateMenuStates() {
    newConnectionMenu.isEnabled = connectItemStates[state.rawValue]
    disconnectMenu.isEnabled = disconnectItemStates[state.rawValue]
    downloadMenu.isEnabled = downloadItemStates[state.rawValue]
    uploadMenu.isEnabled = uploadItemStates[state.rawValue]
    makeFolderMenu.isEnabled = makeFolderItemStates[state.rawValue]
    renameFileMenu.isEnabled = renameFileItemStates[state.rawValue]
    changePermissionsMenu.isEnabled = changePermissionsItemStates[state.rawValue]
    refreshMenu.isEnabled = refreshItemStates[state.rawValue]
    deleteFileMenu.isEnabled = deleteFileItemStates[state.rawValue]
  }
  
  @IBAction func onNewConnection(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: ConnectNotification), object: nil)
  }
  
  @IBAction func onDisonnect(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: DisconnectNotification), object: nil)
  }
  
  @IBAction func onDownload(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: DownloadNotification), object: nil)
  }
  
  @IBAction func onUpload(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: UploadNotification), object: nil)
  }
  
  @IBAction func onMakeDirectory(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: MakeDirectoryNotification), object: nil)
  }
  
  @IBAction func onRenameFile(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: RenameFileNotification), object: nil)
  }
  
  @IBAction func onChangePermissions(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: ChangePermissionsNotification), object: nil)
  }
  
  @IBAction func onRefresh(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: RefreshNotification), object: nil)
  }
  
  @IBAction func onDeleteFile(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: DeleteFileNotification), object: nil)
  }
  
  @objc func didConnect(_ notification: Notification) {
    state = .connectingNoSelection
    updateMenuStates()
  }
  
  @objc func didDisconnect(_ notification: Notification) {
    state = .disconnected
    updateMenuStates()
  }
  
  @objc func fileListSelectionChanged(_ notification: Notification) {
    if notification.userInfo == nil || notification.userInfo!["fileNames"] == nil {
      return
    }
    let fileNames = notification.userInfo!["fileNames"] as! [String]
    if fileNames.count == 0 {
      state = .connectingNoSelection
    }
    else if fileNames.count == 1 {
      state = .connectingOneSelection
    }
    else {
      state = .connectingMultipleSelection
    }
    updateMenuStates()
  }
}

