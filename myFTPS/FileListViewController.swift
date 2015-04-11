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
    
    tableView.setDataSource(self)
    tableView.setDelegate(self)
    tableView.dragDelegate = self
    tableView.registerForDraggedTypes([NSFilenamesPboardType])
    tableView.target = self
    tableView.doubleAction = "tableViewDoubleClicked:"
    
    let nc = NSNotificationCenter.defaultCenter()
    nc.addObserver(self, selector: "makeDirectory:", name: MakeDirectoryNotification, object: nil)
    nc.addObserver(self, selector: "renameFile:", name: RenameFileNotification, object: nil)
    nc.addObserver(self, selector: "changePermissions:", name: ChangePermissionsNotification, object: nil)
    nc.addObserver(self, selector: "deleteFile:", name: DeleteFileNotification, object: nil)
    nc.addObserver(self, selector: "upload:", name: UploadNotification, object: nil)
    nc.addObserver(self, selector: "download:", name: DownloadNotification, object: nil)
    nc.addObserver(self, selector: "refresh:", name: RefreshNotification, object: nil)
    nc.addObserver(self, selector: "didConnect:", name: DidConnectNotification, object: nil)
    nc.addObserver(self, selector: "didDisconnect:", name: DidDisconnectNotification, object: nil)
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    if firstInit {
      pathControl.URL = NSURL(string: "")
      firstInit = false
    }
  }
  
  deinit {
    let nc = NSNotificationCenter.defaultCenter()
    nc.removeObserver(self)
  }
  
  var downloadFolder: String {
    let fm = NSFileManager.defaultManager()
    let url = fm.URLsForDirectory(NSSearchPathDirectory.DownloadsDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first as! NSURL?
    let downloadFolderPath = url!.path!
    return downloadFolderPath
  }
  
  var selectedFileListItems: [FileListItem] {
    let indexes = self.tableView.selectedRowIndexes
    var result = [FileListItem]()
    indexes.enumerateIndexesUsingBlock { (index, stop) -> Void in
      if 1 <= index && index < self.fileList.count + 1 {
        result.append(self.fileList[index - 1])
      }
    }
    return result
  }

  // MARK: - Notification response
  
  func makeDirectory(notification: NSNotification) {
    performSegueWithIdentifier("makeDirectory", sender: self)
  }
  
  func renameFile(notification: NSNotification) {
    performSegueWithIdentifier("renameFile", sender: self)
  }
  
  func changePermissions(notification: NSNotification) {
    performSegueWithIdentifier("changePermissions", sender: self)
  }
  
  func deleteFile(notification: NSNotification) {
    performSegueWithIdentifier("deleteFile", sender: self)
  }
  
  func download(notification: NSNotification) {
    prepareDownload(selectedFileListItems)
  }
  
  func upload(notification: NSNotification) {
    if FTPSManager.sharedInstance.activeSession == nil {
      return
    }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = true
    panel.beginSheetModalForWindow(self.view.window!, completionHandler: { (result) -> Void in
      if result == NSFileHandlingPanelOKButton {
        let urls = panel.URLs as! [NSURL]
        if urls.count > 0 {
          var filePaths = [String]()
          for url in urls {
            filePaths.append(url.path!)
          }
          self.prepareUpload(filePaths)
        }
      }
    })
  }
  
  func prepareUpload(filePaths: [String]) {
    var fileNames = Set<String>()
    for filePath in filePaths {
      fileNames.insert(filePath.lastPathComponent)
    }
    var numberOfOverwriteFiles = 0
    for fileItem in self.fileList {
      if fileNames.contains(fileItem.fileName) {
        numberOfOverwriteFiles++
      }
    }
    if numberOfOverwriteFiles > 0 {
      let alert = NSAlert()
      alert.messageText = "The target files already exist. Overwrite?"
      alert.informativeText = "\(numberOfOverwriteFiles) files will be overwritten."
      alert.addButtonWithTitle("Cancel")
      alert.addButtonWithTitle("Overwrite")
      alert.alertStyle = NSAlertStyle.WarningAlertStyle
      alert.beginSheetModalForWindow(self.view.window!, completionHandler: { (resp) -> Void in
        if resp == NSAlertSecondButtonReturn {
          self.performUpload(filePaths)
        }
      })
    }
    else {
      performUpload(filePaths)
    }
  }
  
  func performUpload(filePaths: [String]) {
    let uploadViewController = self.storyboard!.instantiateControllerWithIdentifier("UploadViewController") as! UploadViewController
    uploadViewController.activeSession = FTPSManager.sharedInstance.activeSession
    uploadViewController.delegate = self
    uploadViewController.filePaths = filePaths
    self.presentViewControllerAsSheet(uploadViewController)
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskStartNotification, object: nil))
  }
  
  func prepareDownload(fileItems: [FileListItem]) {
    let fm = NSFileManager.defaultManager()
    var error: NSError?
    let files = fm.contentsOfDirectoryAtPath(self.downloadFolder, error: &error)
    if error != nil {
      let alert = NSAlert(error: error!)
      alert.runModal()
      return
    }
    var fileNames = Set<String>()
    for file in files! as! [String] {
      fileNames.insert(file)
    }
    
    var numberOfOverwriteFiles = 0
    for fileItem in fileItems {
      if fileNames.contains(fileItem.fileName) {
        numberOfOverwriteFiles++
      }
    }
    if numberOfOverwriteFiles > 0 {
      let alert = NSAlert()
      alert.messageText = "The target files already exist. Overwrite?"
      alert.informativeText = "\(numberOfOverwriteFiles) files will be overwritten."
      alert.addButtonWithTitle("Cancel")
      alert.addButtonWithTitle("Overwrite")
      alert.alertStyle = NSAlertStyle.WarningAlertStyle
      alert.beginSheetModalForWindow(self.view.window!, completionHandler: { (resp) -> Void in
        if resp == NSAlertSecondButtonReturn {
          self.performDownload(fileItems)
        }
      })
    }
    else {
      performDownload(fileItems)
    }
  }

  func performDownload(fileItems: [FileListItem]) {
    let downloadViewController = self.storyboard!.instantiateControllerWithIdentifier("DownloadViewController") as! DownloadViewController
    downloadViewController.activeSession = FTPSManager.sharedInstance.activeSession
    downloadViewController.delegate = self
    downloadViewController.fileList = fileItems
    downloadViewController.downloadFolderPath = downloadFolder
    self.presentViewControllerAsSheet(downloadViewController)
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskStartNotification, object: nil))
  }
  
  func refresh(notification: NSNotification) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if activeSession == nil {
      return
    }
    let path = activeSession!.currentPath
    activeSession!.changeDirectory(path)
  }
  
  func didConnect(notification: NSNotification) {
    FTPSManager.sharedInstance.activeSession?.addDelegate(self)
  }
  
  func didDisconnect(notification: NSNotification) {
    fileList.removeAll(keepCapacity: true)
    tableView.reloadData()
    currentPath = ""
    pathControl.URL = NSURL(string: "")
  }
  
  // MARK: - NSSeguePerforming
  override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
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
  
  override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
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
  
  func numberOfRowsInTableView(tableView: NSTableView) -> Int {
    if FTPSManager.sharedInstance.activeSession != nil {
      return fileList.count + 1
    }
    else {
      return 0
    }
  }
  
  func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
    if row == 0 {
      var cell = tableView.makeViewWithIdentifier("parentFolderCell", owner: self) as! NSView
      return cell
    }
    else {
      var cell = tableView.makeViewWithIdentifier("fileCell", owner: self) as! FileCellView
      var listItem = fileList[row - 1]
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
  
  func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    if row == 0 {
      return 20.0
    }
    else {
      return 64.0
    }
  }
  
  func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    var row = tableView.makeViewWithIdentifier("fileRow", owner: self) as! FileRowView?
    if row == nil {
      row = FileRowView(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
      row!.identifier = "fileRow"
    }
    return row
  }

  func tableViewSelectionDidChange(notification: NSNotification) {
    postFileListSelectionChangedNotification()
  }
  
  func postFileListSelectionChangedNotification() {
    let indexes = self.tableView.selectedRowIndexes
    var fileNames = [String]()
    indexes.enumerateIndexesUsingBlock { (index, stop) -> Void in
      if 1 <= index && index < self.fileList.count + 1 {
        fileNames.append(self.fileList[index - 1].fileName)
      }
    }
    let nc = NSNotificationCenter.defaultCenter()
    nc.postNotificationName(FileListSelectionChangedNotification, object: self, userInfo: ["fileNames": fileNames])
  }
  
  func tableViewDoubleClicked(sender: AnyObject) {
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
      var newPath = activeSession!.currentPath.stringByDeletingLastPathComponent
      newPath = NormalizePath(newPath)
      activeSession!.changeDirectory(newPath)
    }
    else {
      let fileItem = self.fileList[index - 1]
      if fileItem.directory == "d" {
        var newPath = activeSession!.currentPath.stringByAppendingPathComponent(fileItem.fileName)
        newPath = NormalizePath(newPath)
        activeSession!.changeDirectory(newPath)
      }
    }
  }
  
  // MARK: - FileListTableViewDragDelegate
  
  func fileListTableView(fileListTableView: FileListTableView, didDragFiles files: [String]) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if activeSession == nil {
      return
    }
    
    // check whether files can be readable and not be directories
    let fm = NSFileManager.defaultManager()
    var filesToUpload = [String]()
    for file in files {
      var isDirectory: ObjCBool = false
      let exist = fm.fileExistsAtPath(file, isDirectory: &isDirectory)
      let readable = fm.isReadableFileAtPath(file)
      if exist && readable && !isDirectory {
        filesToUpload.append(file)
      }
    }
    
    if filesToUpload.count == 0 {
      return
    }
    
    prepareUpload(filesToUpload)
  }
  
  // MARK: - FTPSSessionDelegate
  
  func session(session: FTPSSession, didChangeDirectory path: String, fileList: [FileListItem]) {
    if self.currentPath != path {
      self.currentPath = path
      self.fileList = fileList
      tableView.reloadData()
      self.pathControl.URL = NSURL(string: session.hostName + path)
      Utils.changeIconsOfPathControl(self.pathControl)
    }
    else {
      let oldFileList = self.fileList
      self.fileList = fileList
      
      var added = NSMutableIndexSet()
      var updated = NSMutableIndexSet()
      var deleted = NSMutableIndexSet()
      
      for i in 0 ..< self.fileList.count {
        let newItem = self.fileList[i]
        let index = find(oldFileList, newItem)
        if index == nil {
          added.addIndex(i + 1)
        }
      }
      
      for i in 0 ..< oldFileList.count {
        let oldItem = oldFileList[i]
        let index = find(self.fileList, oldItem)
        if index == nil {
          deleted.addIndex(i + 1)
        }
        else {
          updated.addIndex(i + 1)
        }
      }
      
      tableView.beginUpdates()
      tableView.insertRowsAtIndexes(added, withAnimation: NSTableViewAnimationOptions.SlideDown)
      tableView.removeRowsAtIndexes(deleted, withAnimation: NSTableViewAnimationOptions.SlideDown)
      tableView.reloadDataForRowIndexes(updated, columnIndexes: NSIndexSet(index: 0))
      tableView.endUpdates()
    }
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
    postFileListSelectionChangedNotification()
  }
  
  func session(session: FTPSSession, uploadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress {
    return CurlProgress.Continue
  }
  
  func session(session: FTPSSession, didUploadFile filePath: String, totalFiles: Int, now: Int) {
  }
  
  func session(session: FTPSSession, didUploadAllFiles filePaths: [String]) {
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
  }
  
  func session(session: FTPSSession, downloadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress {
    return CurlProgress.Continue
  }
  
  func session(session: FTPSSession, didDownloadFile filePath: String, totalFiles: Int, now: Int) {
  }
  
  func session(session: FTPSSession, didDownloadAllFiles filePaths: [String]) {
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
  }
  
  func session(session: FTPSSession, didFailWithCurlCode curlCode: CurlCode) {
    let responseCode = session.client.curl.info.responseCode
    let alert = NSAlert()
    alert.messageText = "Operation failed"
    alert.informativeText = "ErrorCode = \(curlCode.rawValue) (\(Curl.errorString(curlCode))), response code = (\(responseCode))"
    alert.alertStyle = NSAlertStyle.CriticalAlertStyle
    alert.runModal()
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
  }
  
  func session(session: FTPSSession, didFailWithError error: FTPSSession.Error) {
    let alert = NSAlert()
    alert.messageText = "Operation failed"
    alert.informativeText = "ErrorCode = \(error.rawValue) (\(error))"
    alert.alertStyle = NSAlertStyle.CriticalAlertStyle
    alert.runModal()
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
  }
  
  func makeDirectoryViewController(makeDirectoryViewController: MakeDirectoryViewController, didFinishWithResult result: MakeDirectoryViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    activeSession!.makeDirectory(result!.directoryName)
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskStartNotification, object: nil))
  }
  
  func renameFileViewController(renameFileViewController: RenameFileViewController, didFinishWithResult result: RenameFileViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    activeSession!.renameFile(result!.oldFileName, newFileName: result!.newFileName)
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskStartNotification, object: nil))
  }
  
  func changePermissionsViewController(changePermissionsViewController: ChangePermissionsViewController, didFinishWithResult result: ChangePermissionsViewControllerResult?) {
    let activeSession = FTPSManager.sharedInstance.activeSession
    if result == nil || activeSession == nil {
      return
    }
    activeSession!.changePermissions(result!.fileName, permissions: result!.permissions)
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskStartNotification, object: nil))
  }
  
  func deleteFileViewController(deleteFileViewController: DeleteFileViewController, didFinishWithResult result: DeleteFileViewControllerResult?) {
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
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskStartNotification, object: nil))
  }
  
  func uploadViewController(uploadViewController: UploadViewController, didFinishedWithResult: UploadViewControllerResult) {
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
  }
  
  func downloadViewController(downloadViewController: DownloadViewController, didFinishedWithResult: DownloadViewControllerResult) {
    NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: TaskEndNotification, object: nil))
  }
}
