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
  case Disconnected = 0
  case ConnectingNoSelection = 1
  case ConnectingOneSelection = 2
  case ConnectingMultipleSelection = 3
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

  var state = ItemState.Disconnected

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let nc = NSNotificationCenter.defaultCenter()
    nc.addObserver(self, selector: "didConnect:", name: DidConnectNotification, object: nil)
    nc.addObserver(self, selector: "didDisconnect:", name: DidDisconnectNotification, object: nil)
    nc.addObserver(self, selector: "fileListSelectionChanged:", name: FileListSelectionChangedNotification, object: nil)
    
    fileMenu.autoenablesItems = false
    operationMenu.autoenablesItems = false
    updateMenuStates()
  }
  
  func applicationWillTerminate(aNotification: NSNotification) {
  }
  
  func updateMenuStates() {
    newConnectionMenu.enabled = connectItemStates[state.rawValue]
    disconnectMenu.enabled = disconnectItemStates[state.rawValue]
    downloadMenu.enabled = downloadItemStates[state.rawValue]
    uploadMenu.enabled = uploadItemStates[state.rawValue]
    makeFolderMenu.enabled = makeFolderItemStates[state.rawValue]
    renameFileMenu.enabled = renameFileItemStates[state.rawValue]
    changePermissionsMenu.enabled = changePermissionsItemStates[state.rawValue]
    refreshMenu.enabled = refreshItemStates[state.rawValue]
    deleteFileMenu.enabled = deleteFileItemStates[state.rawValue]
  }
  
  @IBAction func onNewConnection(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(ConnectNotification, object: nil)
  }
  
  @IBAction func onDisonnect(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(DisconnectNotification, object: nil)
  }
  
  @IBAction func onDownload(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(DownloadNotification, object: nil)
  }
  
  @IBAction func onUpload(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(UploadNotification, object: nil)
  }
  
  @IBAction func onMakeDirectory(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(MakeDirectoryNotification, object: nil)
  }
  
  @IBAction func onRenameFile(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(RenameFileNotification, object: nil)
  }
  
  @IBAction func onChangePermissions(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(ChangePermissionsNotification, object: nil)
  }
  
  @IBAction func onRefresh(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(RefreshNotification, object: nil)
  }
  
  @IBAction func onDeleteFile(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(DeleteFileNotification, object: nil)
  }
  
  func didConnect(notification: NSNotification) {
    state = .ConnectingNoSelection
    updateMenuStates()
  }
  
  func didDisconnect(notification: NSNotification) {
    state = .Disconnected
    updateMenuStates()
  }
  
  func fileListSelectionChanged(notification: NSNotification) {
    if notification.userInfo == nil || notification.userInfo!["fileNames"] == nil {
      return
    }
    let fileNames = notification.userInfo!["fileNames"] as! [String]
    if fileNames.count == 0 {
      state = .ConnectingNoSelection
    }
    else if fileNames.count == 1 {
      state = .ConnectingOneSelection
    }
    else {
      state = .ConnectingMultipleSelection
    }
    updateMenuStates()
  }
}

