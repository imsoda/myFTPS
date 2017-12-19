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
    
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(ServerListViewController.connect(_:)), name: NSNotification.Name(rawValue: ConnectNotification), object: nil)
    nc.addObserver(self, selector: #selector(ServerListViewController.disconnect(_:)), name: NSNotification.Name(rawValue: DisconnectNotification), object: nil)

    serverListOutlineView.dataSource = self
    serverListOutlineView.delegate = self
    serverListOutlineView.target = self
    serverListOutlineView.doubleAction = #selector(ServerListViewController.serverListViewDoubleClicked(_:))
    
    // context menu
    let contextMenu = NSMenu()
    contextMenu.autoenablesItems = false
    
    let renameMenuItem = NSMenuItem()
    renameMenuItem.title = "Rename"
    renameMenuItem.target = self
    renameMenuItem.action = #selector(ServerListViewController.rename)
    renameMenuItem.isEnabled = true
    contextMenu.addItem(renameMenuItem)
    
    let deleteMenuItem = NSMenuItem()
    deleteMenuItem.title = "Delete"
    deleteMenuItem.target = self
    deleteMenuItem.action = #selector(ServerListViewController.delete)
    deleteMenuItem.isEnabled = true
    contextMenu.addItem(deleteMenuItem)
    
    serverListOutlineView.menu = contextMenu
  }
  
  deinit {
    let nc = NotificationCenter.default
    nc.removeObserver(self)
  }
  
  // MARK: - Notifications
  
  @objc func connect(_ notification: Notification) {
    let connectViewController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "connectViewController")) as! ConnectViewController
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
  
  @objc func disconnect(_ notification: Notification) {
    let manager = FTPSManager.sharedInstance;
    manager.activeSession?.disconnect()
    manager.activeSession = nil
    let nc = NotificationCenter.default
    nc.post(name: Notification.Name(rawValue: DidDisconnectNotification), object: self)
  }
  
  // MARK: - NSSeguePerforming
  
  override func shouldPerformSegue(withIdentifier identifier: NSStoryboardSegue.Identifier, sender: Any?) -> Bool {
    if identifier.rawValue == "newConnect" {
      return FTPSManager.sharedInstance.activeSession == nil
    }
    return true
  }
  
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    if segue.identifier == NSStoryboardSegue.Identifier("newConnect") {
      let connectViewController = segue.destinationController as! ConnectViewController
      connectViewController.delegate = self
    }
  }

  // MARK: - ConnectViewControllerDelegate
  
  func connectViewController(_ connectViewController: ConnectViewController, didFinishWithResult result: ConnectViewControllerResult?) {
    if result == nil {
      return
    }
    let manager = FTPSManager.sharedInstance;
    if manager.activeSession != nil {
      return
    }
    let nc = NotificationCenter.default
    nc.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
    manager.activeSession = manager.createSession(result!.hostName, userName: result!.userName, password: result!.password)
    if manager.activeSession == nil {
      let alert = NSAlert()
      alert.messageText = "Failed to connect the server"
      alert.alertStyle = NSAlert.Style.critical
      alert.runModal()
      return
    }
    manager.activeSession!.sslVerificationCallback = self.sslVerificationCallback
    manager.activeSession!.changeDirectory(result!.path)
    addServerListItem(result!.hostName, userName: result!.userName, path: result!.path)
    
    nc.post(name: Notification.Name(rawValue: DidConnectNotification), object: self)
  }

  func sslVerificationCallback(_ ftpsClient: FTPSClient, preverify: OpenSSLPreverify, status: OSStatus, result: SecTrustResultType, certs: [SecCertificate]) {
    if result == SecTrustResultType.proceed || result == SecTrustResultType.unspecified {
      let manager = FTPSManager.sharedInstance;
      manager.activeSession!.setSSLVeirificationResult(OpenSSLVerifyResult.CONTINUE)
      return
    }
    
    var array = [SecCertificate]()
    for cert in certs {
      array.append(cert)
    }
    
    let certificateViewController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "certificateViewController")) as! CertificateViewController
    certificateViewController.certs = certs
    certificateViewController.delegate = self
    self.presentViewControllerAsSheet(certificateViewController)
  }
  
  func certificateViewController(_ certificateViewController: CertificateViewController, didFinishWithResult result: OpenSSLVerifyResult) {
    let manager = FTPSManager.sharedInstance;
    manager.activeSession!.setSSLVeirificationResult(result)
    
    let nc = NotificationCenter.default
    nc.post(name: Notification.Name(rawValue: DidConnectNotification), object: self)
  }
  
  func addServerListItem(_ hostName: String, userName: String, path: String) {
    var index = self.serverList.indexOfItem(hostName, userName, path: path)
    if index >= 0 {
      // same item already exists
      self.serverListOutlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
      return
    }
    
    index = self.serverList.indexOf(itemName: hostName)
    if index < 0 {
      let item = ServerListItem()
      item.itemName = hostName
      item.hostName = hostName
      item.userName = userName
      item.path = path
      index = self.serverList.add(item)
      self.serverListOutlineView.reloadData()
      self.serverListOutlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
      return
    }
    
    var counter = 1
    var itemName = ""
    repeat {
      itemName = "\(hostName) (\(counter))"
      index = self.serverList.indexOf(itemName: itemName)
      counter += 1
    }
    while index >= 0
    
    let item = ServerListItem()
    item.itemName = itemName
    item.hostName = hostName
    item.userName = userName
    item.path = path
    index = self.serverList.add(item)
    self.serverListOutlineView.reloadData()
    self.serverListOutlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
  }

  @objc func rename() {
    let index = self.serverListOutlineView.selectedRow
    if index < 0 {
      return
    }
    let cellView = self.serverListOutlineView.view(atColumn: 0, row: index, makeIfNecessary: true) as! NSTableCellView
    cellView.textField!.isEditable = true
    cellView.textField!.delegate = self
    cellView.textField!.becomeFirstResponder()
    cellView.textField!.tag = index
  }

  override func controlTextDidEndEditing(_ aNotification: Notification) {
    let textField = aNotification.object as! NSTextField
    let index = textField.tag
    let item = serverList[index]
    let newItemName = textField.stringValue
    textField.isEditable = false
    textField.delegate = nil
    
    if self.serverList.indexOf(itemName: newItemName) >= 0 {
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

  @objc func delete() {
    let index = self.serverListOutlineView.selectedRow
    if index < 0 {
      return
    }
    let item = self.serverList[index]
    self.serverList.remove(item)
    self.serverListOutlineView.reloadData()
  }
  
  // MARK: - NSOutlineViewDataSource
  
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil {
      return serverList.count
    }
    return 0
  }
  
  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if item == nil {
      return serverList[index]
    }
    return ""
  }
  
  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    return false
  }
  
  // MARK: - NSOutlineViewDelegate
  
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "serverCell"), owner: self) as! NSTableCellView
    let serverListItem = item as! ServerListItem
    let index = serverList.indexOf(itemName: serverListItem.itemName)
    cell.textField!.stringValue = serverList[index].itemName
    return cell
  }
  
  @objc func serverListViewDoubleClicked(_ sender: AnyObject) {
    let index = self.serverListOutlineView.selectedRow
    if index < 0 {
      return
    }
    if FTPSManager.sharedInstance.activeSession != nil {
      return
    }
    let item = self.serverList[index]
    let nc = NotificationCenter.default
    nc.post(name: Notification.Name(rawValue: ConnectNotification), object: self, userInfo: ["hostName": item.hostName, "userName": item.userName, "path": item.path])
  }
}
