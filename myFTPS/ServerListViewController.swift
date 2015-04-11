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

let ConnectNotification = "ConnectNotification"
let DidConnectNotification = "DidConnectNotification"
let DisconnectNotification = "DisconnectNotification"
let DidDisconnectNotification = "DidDisconnectNotification"

class ServerListViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate, ConnectViewControllerDelegate, CertificateViewControllerDelegate {
  @IBOutlet weak var serverListOutlineView: NSOutlineView!
  var serverList = ServerList()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    let nc = NSNotificationCenter.defaultCenter()
    nc.addObserver(self, selector: "connect:", name: ConnectNotification, object: nil)
    nc.addObserver(self, selector: "disconnect:", name: DisconnectNotification, object: nil)

    serverListOutlineView.setDataSource(self)
    serverListOutlineView.setDelegate(self)
    serverListOutlineView.target = self
    serverListOutlineView.doubleAction = "serverListViewDoubleClicked:"
    
    // context menu
    let contextMenu = NSMenu()
    contextMenu.autoenablesItems = false
    
    let renameMenuItem = NSMenuItem()
    renameMenuItem.title = "Rename"
    renameMenuItem.target = self
    renameMenuItem.action = "rename"
    renameMenuItem.enabled = true
    contextMenu.addItem(renameMenuItem)
    
    let deleteMenuItem = NSMenuItem()
    deleteMenuItem.title = "Delete"
    deleteMenuItem.target = self
    deleteMenuItem.action = "delete"
    deleteMenuItem.enabled = true
    contextMenu.addItem(deleteMenuItem)
    
    serverListOutlineView.menu = contextMenu
  }
  
  deinit {
    let nc = NSNotificationCenter.defaultCenter()
    nc.removeObserver(self)
  }
  
  // MARK: - Notifications
  
  func connect(notification: NSNotification) {
    let connectViewController = self.storyboard!.instantiateControllerWithIdentifier("connectViewController") as! ConnectViewController
    connectViewController.delegate = self
    if let userInfo = notification.userInfo {
      connectViewController.hostName = userInfo["hostName"] != nil ? userInfo["hostName"] as! String : ""
      connectViewController.userName = userInfo["userName"] != nil ? userInfo["userName"] as! String : ""
      connectViewController.password = userInfo["password"] != nil ? userInfo["password"] as! String : ""
      connectViewController.path = userInfo["path"] != nil ? userInfo["path"] as! String : "/"
    }
    else {
      connectViewController.hostName = ""
      connectViewController.userName = ""
      connectViewController.password = ""
      connectViewController.path = "/"
    }
    presentViewControllerAsSheet(connectViewController)
  }
  
  func disconnect(notification: NSNotification) {
    let manager = FTPSManager.sharedInstance;
    manager.activeSession?.disconnect()
    manager.activeSession = nil
    let nc = NSNotificationCenter.defaultCenter()
    nc.postNotificationName(DidDisconnectNotification, object: self)
  }
  
  // MARK: - NSSeguePerforming
  
  override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
    if identifier == "newConnect" {
      return FTPSManager.sharedInstance.activeSession == nil
    }
    return true
  }
  
  override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "newConnect" {
      let connectViewController = segue.destinationController as! ConnectViewController
      connectViewController.delegate = self
    }
  }

  // MARK: - ConnectViewControllerDelegate
  
  func connectViewController(connectViewController: ConnectViewController, didFinishWithResult result: ConnectViewControllerResult?) {
    if result == nil {
      return
    }
    let manager = FTPSManager.sharedInstance;
    if manager.activeSession != nil {
      return
    }
    let nc = NSNotificationCenter.defaultCenter()
    nc.postNotification(NSNotification(name: TaskStartNotification, object: nil))
    manager.activeSession = manager.createSession(result!.hostName, userName: result!.userName, password: result!.password)
    if manager.activeSession == nil {
      let alert = NSAlert()
      alert.messageText = "Failed to connect the server"
      alert.alertStyle = NSAlertStyle.CriticalAlertStyle
      alert.runModal()
      return
    }
    manager.activeSession!.sslVerificationCallback = self.sslVerificationCallback
    manager.activeSession!.changeDirectory(result!.path)
    addServerListItem(result!.hostName, userName: result!.userName, path: result!.path)
    
    nc.postNotificationName(DidConnectNotification, object: self)
  }

  func sslVerificationCallback(ftpsClient: FTPSClient, preverify: OpenSSLPreverify, status: OSStatus, result: SecTrustResultType, certs: [SecCertificateRef]) {
    if result == SecTrustResultType(kSecTrustResultProceed) || result == SecTrustResultType(kSecTrustResultUnspecified) {
      let manager = FTPSManager.sharedInstance;
      manager.activeSession!.setSSLVeirificationResult(OpenSSLVerifyResult.CONTINUE)
      return
    }
    
    var array = NSMutableArray()
    for cert in certs {
      array.addObject(cert)
    }
    
    let certificateViewController = self.storyboard!.instantiateControllerWithIdentifier("certificateViewController") as! CertificateViewController
    certificateViewController.certs = certs
    certificateViewController.delegate = self
    self.presentViewControllerAsSheet(certificateViewController)
  }
  
  func certificateViewController(certificateViewController: CertificateViewController, didFinishWithResult result: OpenSSLVerifyResult) {
    let manager = FTPSManager.sharedInstance;
    manager.activeSession!.setSSLVeirificationResult(result)
    
    let nc = NSNotificationCenter.defaultCenter()
    nc.postNotificationName(DidConnectNotification, object: self)
  }
  
  func addServerListItem(hostName: String, userName: String, path: String) {
    var index = self.serverList.indexOfItem(hostName: hostName, userName: userName, path: path)
    if index >= 0 {
      // same item already exists
      self.serverListOutlineView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
      return
    }
    
    index = self.serverList.indexOfItem(itemName: hostName)
    if index < 0 {
      let item = ServerListItem()
      item.itemName = hostName
      item.hostName = hostName
      item.userName = userName
      item.path = path
      index = self.serverList.add(item)
      self.serverListOutlineView.reloadData()
      self.serverListOutlineView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
      return
    }
    
    var counter = 1
    var itemName = ""
    do {
      itemName = "\(hostName) (\(counter))"
      index = self.serverList.indexOfItem(itemName: itemName)
      ++counter
    }
    while index >= 0
    
    let item = ServerListItem()
    item.itemName = itemName
    item.hostName = hostName
    item.userName = userName
    item.path = path
    index = self.serverList.add(item)
    self.serverListOutlineView.reloadData()
    self.serverListOutlineView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
  }

  func rename() {
    let index = self.serverListOutlineView.selectedRow
    if index < 0 {
      return
    }
    var cellView = self.serverListOutlineView.viewAtColumn(0, row: index, makeIfNecessary: true) as! NSTableCellView
    cellView.textField!.editable = true
    cellView.textField!.delegate = self
    cellView.textField!.becomeFirstResponder()
    cellView.textField!.tag = index
  }

  override func controlTextDidEndEditing(aNotification: NSNotification) {
    let textField = aNotification.object as! NSTextField
    let index = textField.tag
    let item = serverList[index]
    let newItemName = textField.stringValue
    textField.editable = false
    textField.delegate = nil
    
    if self.serverList.indexOfItem(itemName: newItemName) >= 0 {
      // duplicated name
      textField.stringValue = item.itemName
      return
    }
    
    if newItemName == item.itemName {
      // same name
      return
    }
    self.serverList.rename(oldItemName: item.itemName, newItemName: newItemName)
    self.serverListOutlineView.reloadData()
  }

  func delete() {
    let index = self.serverListOutlineView.selectedRow
    if index < 0 {
      return
    }
    let item = self.serverList[index]
    self.serverList.remove(item)
    self.serverListOutlineView.reloadData()
  }
  
  // MARK: - NSOutlineViewDataSource
  
  func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
    if item == nil {
      return serverList.count
    }
    return 0
  }
  
  func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
    if item == nil {
      return serverList[index]
    }
    return ""
  }
  
  func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
    return false
  }
  
  // MARK: - NSOutlineViewDelegate
  
  func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
    var cell = outlineView.makeViewWithIdentifier("serverCell", owner: self) as! NSTableCellView
    let serverListItem = item as! ServerListItem
    let index = serverList.indexOfItem(itemName: serverListItem.itemName)
    cell.textField!.stringValue = serverList[index].itemName
    return cell
  }
  
  func serverListViewDoubleClicked(sender: AnyObject) {
    let index = self.serverListOutlineView.selectedRow
    if index < 0 {
      return
    }
    if FTPSManager.sharedInstance.activeSession != nil {
      return
    }
    let item = self.serverList[index]
    let nc = NSNotificationCenter.defaultCenter()
    nc.postNotificationName(ConnectNotification, object: self, userInfo: ["hostName": item.hostName, "userName": item.userName, "path": item.path])
  }
}
