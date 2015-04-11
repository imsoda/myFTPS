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

let TaskStartNotification = "TaskStartNotification"
let TaskEndNotification = "TaskEndNotification"

class Toolbar: NSToolbar {
  weak var windowController: WindowController?
  override func validateVisibleItems() {
    super.validateVisibleItems()
    windowController?.toolbarValidateVisibleItems()
  }
}

class WindowController: NSWindowController {
  @IBOutlet weak var toolbar: Toolbar!
  @IBOutlet weak var connectButton: NSSegmentedControl!
  @IBOutlet weak var disconnectButton: NSSegmentedControl!
  @IBOutlet weak var makeFolderButton: NSSegmentedControl!
  @IBOutlet weak var renameFileButton: NSSegmentedControl!
  @IBOutlet weak var changePermissionsButton: NSSegmentedControl!
  @IBOutlet weak var deleteFileButton: NSSegmentedControl!
  @IBOutlet weak var downloadButton: NSSegmentedControl!
  @IBOutlet weak var uploadButton: NSSegmentedControl!
  @IBOutlet weak var refreshButton: NSSegmentedControl!
  @IBOutlet weak var progressIndicator: NSProgressIndicator!
  var state = ItemState.Disconnected
  
  override func windowDidLoad() {
    super.windowDidLoad()

    toolbar.windowController = self
    
    let nc = NSNotificationCenter.defaultCenter()
    nc.addObserver(self, selector: "taskStart:", name: TaskStartNotification, object: nil)
    nc.addObserver(self, selector: "taskEnd:", name: TaskEndNotification, object: nil)
    nc.addObserver(self, selector: "didConnect:", name: DidConnectNotification, object: nil)
    nc.addObserver(self, selector: "didDisconnect:", name: DidDisconnectNotification, object: nil)
    nc.addObserver(self, selector: "fileListSelectionChanged:", name: FileListSelectionChangedNotification, object: nil)
  }
  
  deinit {
    let nc = NSNotificationCenter.defaultCenter()
    nc.removeObserver(self)
  }
  
  func toolbarValidateVisibleItems() {
    if toolbar.visibleItems == nil {
      return
    }
    for i in 0 ..< toolbar.visibleItems!.count {
      let item = toolbar.visibleItems![i] as! NSToolbarItem
      if let view = item.view {
        let segmentedControl = view as? NSSegmentedControl
        if segmentedControl == connectButton {
          item.enabled = connectItemStates[state.rawValue]
        }
        else if segmentedControl == disconnectButton {
          item.enabled = disconnectItemStates[state.rawValue]
        }
        else if segmentedControl == makeFolderButton {
          item.enabled = makeFolderItemStates[state.rawValue]
        }
        else if segmentedControl == renameFileButton {
          item.enabled = renameFileItemStates[state.rawValue]
        }
        else if segmentedControl == changePermissionsButton {
          item.enabled = changePermissionsItemStates[state.rawValue]
        }
        else if segmentedControl == deleteFileButton {
          item.enabled = deleteFileItemStates[state.rawValue]
        }
        else if segmentedControl == downloadButton {
          item.enabled = downloadItemStates[state.rawValue]
        }
        else if segmentedControl == uploadButton {
          item.enabled = uploadItemStates[state.rawValue]
        }
        else if segmentedControl == refreshButton {
          item.enabled = refreshItemStates[state.rawValue]
        }
      }
    }
  }
  
  @IBAction func onConnect(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(ConnectNotification, object: self)
  }
  
  @IBAction func onDisconnect(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(DisconnectNotification, object: self)
  }
  
  @IBAction func onMakeDirectory(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(MakeDirectoryNotification, object: self)
  }
  
  @IBAction func onRenameFile(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(RenameFileNotification, object: self)
  }
  
  @IBAction func onChangePermissions(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(ChangePermissionsNotification, object: self)
  }
  
  @IBAction func onDeleteFile(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(DeleteFileNotification, object: self)
  }
  
  @IBAction func onDownload(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(DownloadNotification, object: self)
  }
  
  @IBAction func onUpload(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(UploadNotification, object: self)
  }
  
  @IBAction func onRefresh(sender: AnyObject) {
    NSNotificationCenter.defaultCenter().postNotificationName(RefreshNotification, object: self)
  }
  
  func taskStart(notification: NSNotification) {
    progressIndicator.hidden = false
    progressIndicator.startAnimation(self)
  }
  
  func taskEnd(notification: NSNotification) {
    progressIndicator.stopAnimation(self)
    progressIndicator.hidden = true
  }
  
  func didConnect(notification: NSNotification) {
    state = .ConnectingNoSelection
  }
  
  func didDisconnect(notification: NSNotification) {
    state = .Disconnected
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
  }
}
