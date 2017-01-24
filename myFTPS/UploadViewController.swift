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

func BytesToString(_ bytes: Int) -> String {
  if bytes < 1024 {
    return "\(bytes) bytes"
  }
  else if bytes < 1024 * 1024 {
    let kBytes = Double(bytes) / 1024.0
    let s = NSString(format: "%.2lf K bytes", kBytes)
    return s as String
  }
  else if bytes < 1024 * 1024 * 1024 {
    let mBytes = Double(bytes) / (1024.0 * 1024.0)
    let s = NSString(format: "%.2lf M bytes", mBytes)
    return s as String
  }
  else {
    let gBytes = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
    let s = NSString(format: "%.2lf G bytes", gBytes)
    return s as String
  }
}

func StringFromByteProgress(totalBytes: Int, now: Int) -> String {
  return "\(BytesToString(now)) / \(BytesToString(totalBytes))"
}

func StringFromFileProgress(totalFiles: Int, now: Int) -> String {
  return "\(now) / \(totalFiles) files"
}

protocol UploadViewControllerDelegate: class {
  func uploadViewController(_ uploadViewController: UploadViewController, didFinishedWithResult: UploadViewControllerResult)
}

enum UploadViewControllerResult {
  case ok
  case error
}

class UploadViewController: NSViewController, FTPSSessionDelegate {
  @IBOutlet weak var fileProgressIndicator: NSProgressIndicator!
  @IBOutlet weak var fileProgressLabel: NSTextField!
  @IBOutlet weak var fileNameLabel: NSTextField!
  @IBOutlet weak var byteProgressIndicator: NSProgressIndicator!
  @IBOutlet weak var byteProgressLabel: NSTextField!
  
  weak var delegate: UploadViewControllerDelegate?
  var activeSession: FTPSSession?
  var filePaths: [String]?
  var hasStarted = false
  var stopRequest = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    if hasStarted == false && activeSession != nil && filePaths != nil {
      self.fileProgressIndicator.maxValue = Double(self.filePaths!.count)
      self.fileProgressLabel.stringValue = StringFromFileProgress(totalFiles: self.filePaths!.count, now: 0)
      stopRequest = false
      activeSession!.addDelegate(self)
      activeSession!.upload(filePaths!)
      hasStarted = true
    }
  }
  
  @IBAction func onCancel(_ sender: AnyObject) {
    stopRequest = true
  }
  
  func cleanup() {
    activeSession?.removeDelegate(self)
    activeSession = nil
    filePaths = nil
    hasStarted = false
    stopRequest = false
  }
  
  func session(_ session: FTPSSession, uploadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress {
    self.fileNameLabel.stringValue = filePath
    self.byteProgressIndicator.maxValue = Double(totalBytes)
    self.byteProgressIndicator.doubleValue = Double(now)
    self.byteProgressLabel.stringValue = "\(BytesToString(now))/\(BytesToString(totalBytes)) bytes"
    return stopRequest ? CurlProgress.abort : CurlProgress.continue
  }
  
  func session(_ session: FTPSSession, didUploadFile filePath: String, totalFiles: Int, now: Int) {
    self.fileNameLabel.stringValue = filePath
    self.fileProgressIndicator.maxValue = Double(self.filePaths!.count)
    self.fileProgressIndicator.doubleValue = Double(now)
    self.fileProgressLabel.stringValue = StringFromFileProgress(totalFiles: totalFiles, now: now)
  }
  
  func session(_ session: FTPSSession, didUploadAllFiles filePaths: [String]) {
    delegate?.uploadViewController(self, didFinishedWithResult: UploadViewControllerResult.ok)
    cleanup()
    presenting?.dismissViewController(self)
  }
  
  func session(_ session: FTPSSession, didFailWithCurlCode curlCode: CurlCode) {
    delegate?.uploadViewController(self, didFinishedWithResult: UploadViewControllerResult.error)
    cleanup()
    presenting?.dismissViewController(self)
  }
  
  func session(_ session: FTPSSession, didFailWithError error: FTPSSession.Error) {
    delegate?.uploadViewController(self, didFinishedWithResult: UploadViewControllerResult.error)
    cleanup()
    presenting?.dismissViewController(self)
  }

  func session(_ session: FTPSSession, didChangeDirectory path: String, fileList: [FileListItem]) {}
  func session(_ session: FTPSSession, downloadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress { return CurlProgress.continue }
  func session(_ session: FTPSSession, didDownloadFile filePath: String, totalFiles: Int, now: Int) {}
  func session(_ session: FTPSSession, didDownloadAllFiles filePaths: [String]) {}
}
