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
  var state = ItemState.disconnected
  
  override func windowDidLoad() {
    super.windowDidLoad()

    toolbar.windowController = self
    
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(WindowController.taskStart(_:)), name: NSNotification.Name(rawValue: TaskStartNotification), object: nil)
    nc.addObserver(self, selector: #selector(WindowController.taskEnd(_:)), name: NSNotification.Name(rawValue: TaskEndNotification), object: nil)
    nc.addObserver(self, selector: #selector(WindowController.didConnect(_:)), name: NSNotification.Name(rawValue: DidConnectNotification), object: nil)
    nc.addObserver(self, selector: #selector(WindowController.didDisconnect(_:)), name: NSNotification.Name(rawValue: DidDisconnectNotification), object: nil)
    nc.addObserver(self, selector: #selector(WindowController.fileListSelectionChanged(_:)), name: NSNotification.Name(rawValue: FileListSelectionChangedNotification), object: nil)
  }
  
  deinit {
    let nc = NotificationCenter.default
    nc.removeObserver(self)
  }
  
  func toolbarValidateVisibleItems() {
    if toolbar.visibleItems == nil {
      return
    }
    for i in 0 ..< toolbar.visibleItems!.count {
      let item = toolbar.visibleItems![i] 
      if let view = item.view {
        let segmentedControl = view as? NSSegmentedControl
        if segmentedControl == connectButton {
          item.isEnabled = connectItemStates[state.rawValue]
        }
        else if segmentedControl == disconnectButton {
          item.isEnabled = disconnectItemStates[state.rawValue]
        }
        else if segmentedControl == makeFolderButton {
          item.isEnabled = makeFolderItemStates[state.rawValue]
        }
        else if segmentedControl == renameFileButton {
          item.isEnabled = renameFileItemStates[state.rawValue]
        }
        else if segmentedControl == changePermissionsButton {
          item.isEnabled = changePermissionsItemStates[state.rawValue]
        }
        else if segmentedControl == deleteFileButton {
          item.isEnabled = deleteFileItemStates[state.rawValue]
        }
        else if segmentedControl == downloadButton {
          item.isEnabled = downloadItemStates[state.rawValue]
        }
        else if segmentedControl == uploadButton {
          item.isEnabled = uploadItemStates[state.rawValue]
        }
        else if segmentedControl == refreshButton {
          item.isEnabled = refreshItemStates[state.rawValue]
        }
      }
    }
  }
  
  @IBAction func onConnect(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: ConnectNotification), object: self)
  }
  
  @IBAction func onDisconnect(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: DisconnectNotification), object: self)
  }
  
  @IBAction func onMakeDirectory(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: MakeDirectoryNotification), object: self)
  }
  
  @IBAction func onRenameFile(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: RenameFileNotification), object: self)
  }
  
  @IBAction func onChangePermissions(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: ChangePermissionsNotification), object: self)
  }
  
  @IBAction func onDeleteFile(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: DeleteFileNotification), object: self)
  }
  
  @IBAction func onDownload(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: DownloadNotification), object: self)
  }
  
  @IBAction func onUpload(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: UploadNotification), object: self)
  }
  
  @IBAction func onRefresh(_ sender: AnyObject) {
    NotificationCenter.default.post(name: Notification.Name(rawValue: RefreshNotification), object: self)
  }
  
  func taskStart(_ notification: Notification) {
    progressIndicator.isHidden = false
    progressIndicator.startAnimation(self)
  }
  
  func taskEnd(_ notification: Notification) {
    progressIndicator.stopAnimation(self)
    progressIndicator.isHidden = true
  }
  
  func didConnect(_ notification: Notification) {
    state = .connectingNoSelection
  }
  
  func didDisconnect(_ notification: Notification) {
    state = .disconnected
  }
  
  func fileListSelectionChanged(_ notification: Notification) {
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
  }
}
