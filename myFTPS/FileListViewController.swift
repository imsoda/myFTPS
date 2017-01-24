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

let MakeDirectoryNotification = "MakeDirectoryNotification"
let RenameFileNotification = "RenameFileNotification"
let ChangePermissionsNotification = "ChangePermissionsNotification"
let DeleteFileNotification = "DeleteFileNotification"
let DownloadNotification = "DownloadNotification"
let UploadNotification = "UploadNotification"
let RefreshNotification = "RefreshNotification"
let FileListSelectionChangedNotification = "FileListSelectionChangedNotification"

class FileListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, FileListTableViewDragDelegate, FTPSSessionDelegate,  MakeDirectoryViewControllerDelegate, RenameFileViewControllerDelegate, ChangePermissionsViewControllerDelegate, DeleteFileViewControllerDelegate, UploadViewControllerDelegate, DownloadViewControllerDelegate {
  let fileImage = NSImage(named: "file")
  let folderImage = NSImage(named: "folder")
  @IBOutlet weak var pathControl: NSPathControl!
  @IBOutlet weak var tableView: FileListTableView!
  var currentPath = ""
  var fileList = [FileListItem]()
  var firstInit = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.dataSource = self
    tableView.delegate = self
    tableView.dragDelegate = self
    tableView.register(forDraggedTypes: [NSFilenamesPboardType])
    tableView.target = self
    tableView.doubleAction = #selector(FileListViewController.tableViewDoubleClicked(_:))
    
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(FileListViewController.makeDirectory(_:)), name: NSNotification.Name(rawValue: MakeDirectoryNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.renameFile(_:)), name: NSNotification.Name(rawValue: RenameFileNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.changePermissions(_:)), name: NSNotification.Name(rawValue: ChangePermissionsNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.deleteFile(_:)), name: NSNotification.Name(rawValue: DeleteFileNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.upload(_:)), name: NSNotification.Name(rawValue: UploadNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.download(_:)), name: NSNotification.Name(rawValue: DownloadNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.refresh(_:)), name: NSNotification.Name(rawValue: RefreshNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.didConnect(_:)), name: NSNotification.Name(rawValue: DidConnectNotification), object: nil)
    nc.addObserver(self, selector: #selector(FileListViewController.didDisconnect(_:)), name: NSNotification.Name(rawValue: DidDisconnectNotification), object: nil)
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    if firstInit {
      pathControl.url = URL(string: "")
      firstInit = false
    }
  }
  
  deinit {
    let nc = NotificationCenter.default
    nc.removeObserver(self)
  }
  
  var downloadFolder: String {
    let fm = FileManager.default
    let url = fm.urls(for: FileManager.SearchPathDirectory.downloadsDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first 
    let downloadFolderPath = url!.path
    return downloadFolderPath
  }
  
  var selectedFileListItems: [FileListItem] {
    let indexes = self.tableView.selectedRowIndexes
    var result = [FileListItem]()
    
    for index in indexes {
      if 1 <= index && index < self.fileList.count + 1 {
        result.append(self.fileList[index - 1])
      }
    }
    return result
  }

  // MARK: - Notification response
  
  func makeDirectory(_ notification: Notification) {
    performSegue(withIdentifier: "makeDirectory", sender: self)
  }
  
  func renameFile(_ notification: Notification) {
    performSegue(withIdentifier: "renameFile", sender: self)
  }
  
  func changePermissions(_ notification: Notification) {
    performSegue(withIdentifier: "changePermissions", sender: self)
  }
  
  func deleteFile(_ notification: Notification) {
    performSegue(withIdentifier: "deleteFile", sender: self)
  }
  
  func download(_ notification: Notification) {
    prepareDownload(selectedFileListItems)
  }
  
  func upload(_ notification: Notification) {
    if FTPSManager.sharedInstance.activeSession == nil {
      return
    }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = true
    panel.beginSheetModal(for: self.view.window!, completionHandler: { (result) -> Void in
      if result == NSFileHandlingPanelOKButton {
        let urls = panel.urls 
        if urls.count > 0 {
          var filePaths = [String]()
          for url in urls {
            filePaths.append(url.path)
          }
          self.prepareUpload(filePaths)
        }
      }
    })
  }
  
  func prepareUpload(_ filePaths: [String]) {
    var fileNames = Set<String>()
    for filePath in filePaths {
      fileNames.insert((filePath as NSString).lastPathComponent)
    }
    var numberOfOverwriteFiles = 0
    for fileItem in self.fileList {
      if fileNames.contains(fileItem.fileName) {
        numberOfOverwriteFiles += 1
      }
    }
    if numberOfOverwriteFiles > 0 {
      let alert = NSAlert()
      alert.messageText = "The target files already exist. Overwrite?"
      alert.informativeText = "\(numberOfOverwriteFiles) files will be overwritten."
      alert.addButton(withTitle: "Cancel")
      alert.addButton(withTitle: "Overwrite")
      alert.alertStyle = NSAlertStyle.warning
      alert.beginSheetModal(for: self.view.window!, completionHandler: { (resp) -> Void in
        if resp == NSAlertSecondButtonReturn {
          self.performUpload(filePaths)
        }
      })
    }
    else {
      performUpload(filePaths)
    }
  }
  
  func performUpload(_ filePaths: [String]) {
    let uploadViewController = self.storyboard!.instantiateController(withIdentifier: "UploadViewController") as! UploadViewController
    uploadViewController.activeSession = FTPSManager.sharedInstance.activeSession
    uploadViewController.delegate = self
    uploadViewController.filePaths = filePaths
    self.presentViewControllerAsSheet(uploadViewController)
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
  }
  
  func prepareDownload(_ fileItems: [FileListItem]) {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: self.downloadFolder) else {
      let alert = NSAlert()
      alert.messageText = "Failed to access the directory '\(self.downloadFolder)'"
      alert.runModal()
      return
    }
    var fileNames = Set<String>()
    for file in files {
      fileNames.insert(file)
    }
    
    var numberOfOverwriteFiles = 0
    for fileItem in fileItems {
      if fileNames.contains(fileItem.fileName) {
        numberOfOverwriteFiles += 1
      }
    }
    if numberOfOverwriteFiles > 0 {
      let alert = NSAlert()
      alert.messageText = "The target files already exist. Overwrite?"
      alert.informativeText = "\(numberOfOverwriteFiles) files will be overwritten."
      alert.addButton(withTitle: "Cancel")
      alert.addButton(withTitle: "Overwrite")
      alert.alertStyle = NSAlertStyle.warning
      alert.beginSheetModal(for: self.view.window!, completionHandler: { (resp) -> Void in
        if resp == NSAlertSecondButtonReturn {
          self.performDownload(fileItems)
        }
      })
    }
    else {
      performDownload(fileItems)
    }
  }

  func performDownload(_ fileItems: [FileListItem]) {
    let downloadViewController = self.storyboard!.instantiateController(withIdentifier: "DownloadViewController") as! DownloadViewController
    downloadViewController.activeSession = FTPSManager.sharedInstance.activeSession
    downloadViewController.delegate = self
    downloadViewController.fileList = fileItems
    downloadViewController.downloadFolderPath = downloadFolder
    self.presentViewControllerAsSheet(downloadViewController)
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
  }
  
  func refresh(_ notification: Notification) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if activeSession == nil {
      return
    }
    let path = activeSession!.currentPath
    activeSession!.changeDirectory(path)
  }
  
  func didConnect(_ notification: Notification) {
    FTPSManager.sharedInstance.activeSession?.addDelegate(self)
  }
  
  func didDisconnect(_ notification: Notification) {
    fileList.removeAll(keepingCapacity: true)
    tableView.reloadData()
    currentPath = ""
    pathControl.url = URL(string: "")
  }
  
  // MARK: - NSSeguePerforming
  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if identifier == "renameFile" {
      return activeSession != nil && selectedFileListItems.count == 1
    }
    else if identifier == "changePermissions" {
      return activeSession != nil && selectedFileListItems.count == 1
    }
    else if identifier == "deleteFile" {
      return activeSession != nil && selectedFileListItems.count == 1
    }
    else if identifier == "download" {
      return activeSession != nil && selectedFileListItems.count > 0
    }
    return true
  }
  
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    if segue.identifier == "makeDirectory" {
      let makeDirectoryViewController = segue.destinationController as! MakeDirectoryViewController
      makeDirectoryViewController.delegate = self
    }
    else if segue.identifier == "renameFile" {
      if selectedFileListItems.count == 1 {
        let selectedFile = selectedFileListItems.first!
        let renameFileViewController = segue.destinationController as! RenameFileViewController
        renameFileViewController.delegate = self
        renameFileViewController.oldFileName = selectedFile.fileName
      }
    }
    else if segue.identifier == "changePermissions" {
      if selectedFileListItems.count == 1 {
        let selectedFile = selectedFileListItems.first!
        let changePermissionsViewConteroller = segue.destinationController as! ChangePermissionsViewController
        changePermissionsViewConteroller.delegate = self
        changePermissionsViewConteroller.fileListItem = selectedFile
      }
    }
    else if segue.identifier == "deleteFile" {
      if selectedFileListItems.count == 1 {
        let selectedFile = selectedFileListItems.first!
        let deleteFileViewController = segue.destinationController as! DeleteFileViewController
        deleteFileViewController.delegate = self
        deleteFileViewController.fileItem = selectedFile
      }
    }
    else if segue.identifier == "download" {
      if selectedFileListItems.count > 0 {
        let downloadViewController = segue.destinationController as! DownloadViewController
        downloadViewController.activeSession = FTPSManager.sharedInstance.activeSession
        downloadViewController.delegate = self
        downloadViewController.fileList = selectedFileListItems
        downloadViewController.downloadFolderPath = downloadFolder
      }
    }
  }
  
  // MARK: - NSTableViewDataSource
  
  func numberOfRows(in tableView: NSTableView) -> Int {
    if FTPSManager.sharedInstance.activeSession != nil {
      return fileList.count + 1
    }
    else {
      return 0
    }
  }
  
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    if row == 0 {
      let cell = tableView.make(withIdentifier: "parentFolderCell", owner: self)
      return cell
    }
    else {
      let cell = tableView.make(withIdentifier: "fileCell", owner: self) as! FileCellView
      let listItem = fileList[row - 1]
      if listItem.directory == "d" {
        cell.fileImageView.image = self.folderImage
      }
      else {
        cell.fileImageView.image = self.fileImage
      }
      cell.fileNameLabel.stringValue = listItem.fileName
      cell.userPermissionsLabel.stringValue = listItem.userPermissions
      cell.groupPermissionsLabel.stringValue = listItem.groupPermissions
      cell.otherPermissionsLabel.stringValue = listItem.otherPermissions
      cell.ownerLabel.stringValue = listItem.owner
      cell.groupLabel.stringValue = listItem.group
      cell.dateLabel.stringValue = listItem.date
      return cell
    }
  }
  
  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    if row == 0 {
      return 20.0
    }
    else {
      return 64.0
    }
  }
  
  func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    var row = tableView.make(withIdentifier: "fileRow", owner: self) as! FileRowView?
    if row == nil {
      row = FileRowView(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
      row!.identifier = "fileRow"
    }
    return row
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    postFileListSelectionChangedNotification()
  }
  
  func postFileListSelectionChangedNotification() {
    let indexes = self.tableView.selectedRowIndexes
    var fileNames = [String]()
    for index in indexes {
      if 1 <= index && index < self.fileList.count + 1 {
        fileNames.append(self.fileList[index - 1].fileName)
      }
    }
    let nc = NotificationCenter.default
    nc.post(name: Notification.Name(rawValue: FileListSelectionChangedNotification), object: self, userInfo: ["fileNames": fileNames])
  }
  
  func tableViewDoubleClicked(_ sender: AnyObject) {
    let index = tableView.selectedRow
    if (0 <= index && index < self.fileList.count + 1) == false {
      return
    }
    
    let activeSession = FTPSManager.sharedInstance.activeSession
    if activeSession == nil {
      return
    }
    
    if index == 0 {
      // move to parent directory
      if activeSession!.currentPath == "/" {
        return
      }
      var newPath = (activeSession!.currentPath as NSString).deletingLastPathComponent
      newPath = NormalizePath(newPath)
      activeSession!.changeDirectory(newPath)
    }
    else {
      let fileItem = self.fileList[index - 1]
      if fileItem.directory == "d" {
        var newPath = (activeSession!.currentPath as NSString).appendingPathComponent(fileItem.fileName)
        newPath = NormalizePath(newPath)
        activeSession!.changeDirectory(newPath)
      }
    }
  }
  
  // MARK: - FileListTableViewDragDelegate
  
  func fileListTableView(_ fileListTableView: FileListTableView, didDragFiles files: [String]) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if activeSession == nil {
      return
    }
    
    // check whether files can be readable and not be directories
    let fm = FileManager.default
    var filesToUpload = [String]()
    for file in files {
      var isDirectory: ObjCBool = false
      let exist = fm.fileExists(atPath: file, isDirectory: &isDirectory)
      let readable = fm.isReadableFile(atPath: file)
      if exist && readable && !isDirectory.boolValue {
        filesToUpload.append(file)
      }
    }
    
    if filesToUpload.count == 0 {
      return
    }
    
    prepareUpload(filesToUpload)
  }
  
  // MARK: - FTPSSessionDelegate
  
  func session(_ session: FTPSSession, didChangeDirectory path: String, fileList: [FileListItem]) {
    if self.currentPath != path {
      self.currentPath = path
      self.fileList = fileList
      tableView.reloadData()
      self.pathControl.url = URL(string: session.hostName + path)
      Utils.changeIcons(of: self.pathControl)
    }
    else {
      let oldFileList = self.fileList
      self.fileList = fileList
      
      var added = IndexSet()
      var updated = IndexSet()
      var deleted = IndexSet()
      
      for i in 0 ..< self.fileList.count {
        let newItem = self.fileList[i]
        let index =  oldFileList.index(of: newItem)
        if index == nil {
          added.insert(i + 1)
        }
      }
      
      for i in 0 ..< oldFileList.count {
        let oldItem = oldFileList[i]
        let index = self.fileList.index(of: oldItem)
        if index == nil {
          deleted.insert(i + 1)
        }
        else {
          updated.insert(i + 1)
        }
      }
      
      tableView.beginUpdates()
      tableView.insertRows(at: added as IndexSet, withAnimation: NSTableViewAnimationOptions.slideDown)
      tableView.removeRows(at: deleted as IndexSet, withAnimation: NSTableViewAnimationOptions.slideDown)
      tableView.reloadData(forRowIndexes: updated as IndexSet, columnIndexes: IndexSet(integer: 0))
      tableView.endUpdates()
    }
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
    postFileListSelectionChangedNotification()
  }
  
  func session(_ session: FTPSSession, uploadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress {
    return CurlProgress.continue
  }
  
  func session(_ session: FTPSSession, didUploadFile filePath: String, totalFiles: Int, now: Int) {
  }
  
  func session(_ session: FTPSSession, didUploadAllFiles filePaths: [String]) {
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
  }
  
  func session(_ session: FTPSSession, downloadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress {
    return CurlProgress.continue
  }
  
  func session(_ session: FTPSSession, didDownloadFile filePath: String, totalFiles: Int, now: Int) {
  }
  
  func session(_ session: FTPSSession, didDownloadAllFiles filePaths: [String]) {
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
  }
  
  func session(_ session: FTPSSession, didFailWithCurlCode curlCode: CurlCode) {
    let responseCode = session.client.curl.info.responseCode
    let alert = NSAlert()
    alert.messageText = "Operation failed"
    alert.informativeText = "ErrorCode = \(curlCode.rawValue) (\(Curl.errorString(curlCode))), response code = (\(responseCode))"
    alert.alertStyle = NSAlertStyle.critical
    alert.runModal()
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
  }
  
  func session(_ session: FTPSSession, didFailWithError error: FTPSSession.Error) {
    let alert = NSAlert()
    alert.messageText = "Operation failed"
    alert.informativeText = "ErrorCode = \(error.rawValue) (\(error))"
    alert.alertStyle = NSAlertStyle.critical
    alert.runModal()
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
  }
  
  func makeDirectoryViewController(_ makeDirectoryViewController: MakeDirectoryViewController, didFinishWithResult result: MakeDirectoryViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    activeSession!.makeDirectory(result!.directoryName)
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
  }
  
  func renameFileViewController(_ renameFileViewController: RenameFileViewController, didFinishWithResult result: RenameFileViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    activeSession!.renameFile(result!.oldFileName, newFileName: result!.newFileName)
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
  }
  
  func changePermissionsViewController(_ changePermissionsViewController: ChangePermissionsViewController, didFinishWithResult result: ChangePermissionsViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    activeSession!.changePermissions(result!.fileName, permissions: result!.permissions)
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
  }
  
  func deleteFileViewController(_ deleteFileViewController: DeleteFileViewController, didFinishWithResult result: DeleteFileViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    if result!.fileItem.directory == "d" {
      activeSession!.removeDirectory(result!.fileItem.fileName)
    }
    else if result!.fileItem.directory == "-" {
      activeSession!.deleteFile(result!.fileItem.fileName)
    }
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskStartNotification), object: nil))
  }
  
  func uploadViewController(_ uploadViewController: UploadViewController, didFinishedWithResult: UploadViewControllerResult) {
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
  }
  
  func downloadViewController(_ downloadViewController: DownloadViewController, didFinishedWithResult: DownloadViewControllerResult) {
    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: TaskEndNotification), object: nil))
  }
}
