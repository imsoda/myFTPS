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

import Foundation

protocol FTPSSessionDelegate: class {
  func session(_ session: FTPSSession, didChangeDirectory path: String, fileList: [FileListItem])
  
  func session(_ session: FTPSSession, uploadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress
  func session(_ session: FTPSSession, didUploadFile filePath: String, totalFiles: Int, now: Int)
  func session(_ session: FTPSSession, didUploadAllFiles filePaths: [String])
  
  func session(_ session: FTPSSession, downloadProgressForFile filePath: String, totalBytes: Int, now: Int) -> CurlProgress
  func session(_ session: FTPSSession, didDownloadFile filePath: String, totalFiles: Int, now: Int)
  func session(_ session: FTPSSession, didDownloadAllFiles filePaths: [String])
  
  func session(_ session: FTPSSession, didFailWithCurlCode curlCode: CurlCode)
  func session(_ session: FTPSSession, didFailWithError error: FTPSSession.Error)
}

class FTPSSession {
  enum Error : Int, CustomStringConvertible {
    case noDownloadFolder = 0
    var description: String {
      get {
        switch self {
        case .noDownloadFolder: return "No download folder"
        }
      }
    }
  }
  
  unowned let manager: FTPSManager
  let identifier: Int
  var client: FTPSClient
  var queue: DispatchQueue
  var delegates = [FTPSSessionDelegate]()
  var sslVerificationCallback: SSLVerificationCallback? {
    get {
      return client.sslVerificationCallback
    }
    set {
      client.sslVerificationCallback = newValue
    }
  }
  
  init(manager: FTPSManager, identifier: Int, hostName: String, userName: String, password: String) {
    self.manager = manager
    self.identifier = identifier
    self.client = FTPSClient(hostName: hostName, userName: userName, password: password)
    self.queue = DispatchQueue(label: "worker", attributes: [])
  }
  
  func indexOfDelegate(_ delegate: FTPSSessionDelegate) -> Int {
    var index: Int = -1
    for i in 0 ..< self.delegates.count {
      if self.delegates[i] === delegate {
        index = i
        break
      }
    }
    return index
  }
  
  func addDelegate(_ delegate: FTPSSessionDelegate) {
    let index = indexOfDelegate(delegate)
    if index < 0 {
      self.delegates.append(delegate)
    }
  }
  
  func removeDelegate(_ delegate: FTPSSessionDelegate) {
    let index = indexOfDelegate(delegate)
    if index >= 0 {
      self.delegates.remove(at: index)
    }
  }
  
  var currentPath: String {
    return client.currentPath
  }
  
  var hostName: String {
    return client.hostName
  }
  
  var userName: String {
    return client.userName
  }
  
  var password: String {
    return client.password
  }
  
  func setSSLVeirificationResult(_ result: OpenSSLVerifyResult) {
    _ = self.client.semaphore.wait(timeout: DispatchTime.distantFuture)
    self.client.verifyResult = result
    self.client.semaphore.signal()
  }
  
  func changeDirectory(_ newPath: String) {
    self.queue.async(execute: { () -> Void in
      let (code, fileList) = self.client.changeDirectory(newPath)
      DispatchQueue.main.async(execute: { () -> Void in
        if code == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: newPath, fileList: fileList!)
          }
        }
        else {
          for delegate in self.delegates {
            delegate.session(self, didFailWithCurlCode: code)
          }
        }
      })
    })
  }
  
  func disconnect() {
    self.client.disconnect()
    self.manager.sessions.remove(at: self.identifier)
    self.delegates.removeAll(keepingCapacity: false)
  }
  
  func upload(_ filePaths: [String]) {
    self.queue.async(execute: { () -> Void in
      var hasError = false
      for i in 0 ..< filePaths.count {
        let filePath = filePaths[i]
        let curlCode = self.client.upload(localPath: filePath, progressCallback: { (downloadTotal, downloadNow, uploadTotal, uploadNow) -> CurlProgress in
          var progress = CurlProgress.continue
          DispatchQueue.main.sync(execute: { () -> Void in
            for delegate in self.delegates {
              let prog = delegate.session(self, uploadProgressForFile: filePath, totalBytes: uploadTotal, now: uploadNow)
              if prog == CurlProgress.abort {
                progress = CurlProgress.abort
              }
            }
          })
          return progress
        })
        DispatchQueue.main.sync(execute: { () -> Void in
          if curlCode == CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didUploadFile: filePath, totalFiles: filePaths.count, now: i)
            }
          }
          else {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: curlCode)
            }
            hasError = true
          }
        })
        if hasError {
          break
        }
      }
      
      DispatchQueue.main.sync(execute: { () -> Void in
        for delegate in self.delegates {
          delegate.session(self, didUploadAllFiles: filePaths)
        }
      })
      
      let (listCode, list) = self.client.changeDirectory(self.client.currentPath)
      DispatchQueue.main.sync(execute: { () -> Void in
        if listCode == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: self.client.currentPath, fileList: list!)
          }
        }
        else {
          for delegate in self.delegates {
            delegate.session(self, didFailWithCurlCode: listCode)
          }
        }
      })

    }) // self.queue
  }
  
  func download(_ filePaths: [String], downloadFolderPath: String) {
    self.queue.async(execute: { () -> Void in
      var hasError = false
      for i in 0 ..< filePaths.count {
        let filePath = filePaths[i]
        let localPath = (downloadFolderPath as NSString).appendingPathComponent(filePath)
        let curlCode = self.client.download(filePath, localPath: localPath, progressCallback: { (downloadTotal, downloadNow, uploadTotal, uploadNow) -> CurlProgress in
          var progress = CurlProgress.continue
          DispatchQueue.main.sync(execute: { () -> Void in
            for delegate in self.delegates {
              let prog = delegate.session(self, downloadProgressForFile: filePath, totalBytes: downloadTotal, now: downloadNow)
              if prog == CurlProgress.abort {
                progress = CurlProgress.abort
              }
            }
          })
          return progress
        })
        DispatchQueue.main.sync(execute: { () -> Void in
          if curlCode == CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didDownloadFile: filePath, totalFiles: filePaths.count, now: i)
            }
          }
          else {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: curlCode)
            }
            hasError = true
          }
        })
        if hasError {
          break
        }
      }
      
      if hasError == false {
        DispatchQueue.main.sync(execute: { () -> Void in
          for delegate in self.delegates {
            delegate.session(self, didDownloadAllFiles: filePaths)
          }
        })
      }
    })
  }
  
  func makeDirectory(_ directoryName: String) {
    self.queue.async(execute: { () -> Void in
      let mkdirCode = self.client.makeDirectory(directoryName)
      let (listCode, list) = self.client.changeDirectory(self.client.currentPath)
      DispatchQueue.main.async(execute: { () -> Void in
        if mkdirCode == CurlCode.OK  && listCode == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: self.client.currentPath, fileList: list!)
          }
        }
        else {
          if mkdirCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: mkdirCode)
            }
          }
          else if listCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: listCode)
            }
          }
        }
      })
    })
  }
  
  func removeDirectory(_ directoryName: String) {
    self.queue.async(execute: { () -> Void in
      let rmdirCode = self.client.removeDirectory(directoryName)
      let (listCode, list) = self.client.changeDirectory(self.client.currentPath)
      DispatchQueue.main.async(execute: { () -> Void in
        if rmdirCode == CurlCode.OK  && listCode == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: self.client.currentPath, fileList: list!)
          }
        }
        else {
          if rmdirCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: rmdirCode)
            }
          }
          else if listCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: listCode)
            }
          }
        }
      })
    })
  }
  
  func renameFile(_ oldFileName: String, newFileName: String) {
    self.queue.async(execute: { () -> Void in
      let renameCode = self.client.renameFile(oldFileName, newName: newFileName)
      let (listCode, list) = self.client.changeDirectory(self.client.currentPath)
      DispatchQueue.main.async(execute: { () -> Void in
        if renameCode == CurlCode.OK  && listCode == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: self.client.currentPath, fileList: list!)
          }
        }
        else {
          if renameCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: renameCode)
            }
          }
          else if listCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: listCode)
            }
          }
        }
      })
    })
  }
  
  func changePermissions(_ fileName: String, permissions: UInt) {
    self.queue.async(execute: { () -> Void in
      let chmodCode = self.client.changePermissions(fileName, permission: permissions)
      let (listCode, list) = self.client.changeDirectory(self.client.currentPath)
      
      DispatchQueue.main.async(execute: { () -> Void in
        if chmodCode == CurlCode.OK  && listCode == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: self.client.currentPath, fileList: list!)
          }
        }
        else {
          if chmodCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: chmodCode)
            }
          }
          else if listCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: listCode)
            }
          }
        }
      })
    })
  }
  
  func deleteFile(_ fileName: String) {
    self.queue.async(execute: { () -> Void in
      let rmCode = self.client.removeFile(fileName)
      let (listCode, list) = self.client.changeDirectory(self.client.currentPath)
      
      DispatchQueue.main.async(execute: { () -> Void in
        if rmCode == CurlCode.OK  && listCode == CurlCode.OK {
          for delegate in self.delegates {
            delegate.session(self, didChangeDirectory: self.client.currentPath, fileList: list!)
          }
        }
        else {
          if rmCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: rmCode)
            }
          }
          else if listCode != CurlCode.OK {
            for delegate in self.delegates {
              delegate.session(self, didFailWithCurlCode: listCode)
            }
          }
        }
      })
    })
  }
  
}
