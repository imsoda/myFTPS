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

public typealias SSLVerificationCallback =
  (ftpsClient: FTPSClient, preverify: OpenSSLPreverify, status: OSStatus, result: SecTrustResultType, certs: [SecCertificateRef]) -> Void

public class FTPSClient {
  let curl = Curl()
  let openSSLHelper = OpenSSLHelper()
  let listParser = FileListParser()
  let hostName: String
  let userName: String
  let password: String
  var currentPath = "/"
  let semaphore = dispatch_semaphore_create(1)
  var verifyResult: OpenSSLVerifyResult? = nil
  var sslVerificationCallback: SSLVerificationCallback? = nil
  
  public init(hostName: String, userName: String, password: String) {
    self.hostName = hostName
    self.userName = userName
    self.password = password
    self.openSSLHelper.hostName = self.hostName
    listParser.exclusionFileNames = [".", ".."]
  }
  
  func disconnect() {
    self.curl.cleanup()
  }
  
  func certVerify(preverify: OpenSSLPreverify, status: OSStatus, result: SecTrustResultType, certs _certs: NSArray) -> OpenSSLVerifyResult {
    var certs = [SecCertificateRef]()
    for _cert in _certs {
      let cert = _cert as! SecCertificateRef
      certs.append(cert)
    }
    var sslResult = OpenSSLVerifyResult.STOP
    if self.sslVerificationCallback != nil {
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        self.sslVerificationCallback!(ftpsClient: self, preverify: preverify, status: status, result: result, certs: certs)
      })
      let waitTime: Int64 = 250 * Int64(NSEC_PER_MSEC)
      while true {
        let time = dispatch_time(DISPATCH_TIME_NOW, waitTime)
        let ret = dispatch_semaphore_wait(self.semaphore, time)
        if ret == 0 {
          if self.verifyResult != nil {
            sslResult = self.verifyResult!
            dispatch_semaphore_signal(self.semaphore)
            break
          }
          else {
            dispatch_semaphore_signal(self.semaphore)
            NSThread.sleepForTimeInterval(0.25)
            continue
          }
        }
      }
    }
    return sslResult
  }
  
  func setAuthParams() {
    self.curl.username = self.userName
    self.curl.password = self.password
    self.curl.useSSL = CurlUseSSL.All
    self.curl.SSLVerifyHost = false
    self.curl.SSLVerifyPeer = false
    self.curl.SSLCtxFunction = {(curl, sslCtx) -> CurlCode in
      self.openSSLHelper.registerCertVerifyCallback(sslCtx);
      self.openSSLHelper.certVerifyCallback = {(preverify, status, result, certs) in
        self.certVerify(preverify, status: status, result: result, certs: certs)
      }
      return CurlCode.OK
    }
  }
  
  public typealias ProgressCallback = (downloadTotal: Int, downloadNow: Int,
    uploadTotal: Int, uploadNow: Int) -> CurlProgress
  
  public func download(remoteFileName: String, localPath: String, progressCallback: ProgressCallback) -> CurlCode {
    let coordinator = NSFileCoordinator()
    let localURL = NSURL(fileURLWithPath: localPath)
    var coordinatorError: NSError?
    var code: CurlCode = CurlCode.ReadError
    coordinator.coordinateWritingItemAtURL(localURL!,
      options: NSFileCoordinatorWritingOptions(0),
      error: &coordinatorError) { (localURL) -> Void in
        
        let localPath = localURL.path!
        let outputStream = NSOutputStream(toFileAtPath: localPath, append: false)
        if outputStream == nil {
          fatalError("failed to create output stream")
        }
        outputStream!.open()
        self.curl.reset()
        var url = "ftp://\(self.hostName)\(self.currentPath)"
        url = url.hasSuffix("/") ? "\(url)\(remoteFileName)" : "\(url)/\(remoteFileName)"
        self.curl.URL = url
        self.setAuthParams()
        self.curl.writeFunction = {(buffer, size) in
          let n = outputStream!.write(buffer, maxLength: size)
          return n
        }
        self.curl.noProgress = false
        self.curl.xferInfoFunction = progressCallback
        code = self.curl.perform()
        outputStream!.close()
    }
    if coordinatorError != nil {
      fatalError(coordinatorError!.description)
    }
    return code
  }
  
  func upload(localPath: String, progressCallback: ProgressCallback) -> CurlCode {
    let fileName = localPath.lastPathComponent
    let coordinator = NSFileCoordinator()
    let localURL = NSURL(fileURLWithPath: localPath)
    var coordinatorError: NSError?
    var code: CurlCode = CurlCode.UploadFailed
    coordinator.coordinateReadingItemAtURL(localURL!,
      options: NSFileCoordinatorReadingOptions(0),
      error: &coordinatorError) { (localURL) -> Void in
        
        let localPath = localURL.path!
        let fileManager = NSFileManager.defaultManager()
        var error: NSError?
        let attributes = fileManager.attributesOfItemAtPath(localPath, error: &error)
        if error != nil || attributes == nil {
          fatalError("failed to get file attribute")
        }
        let fileSize = attributes![NSFileSize] as! NSNumber
        let inputStream = NSInputStream(fileAtPath: localPath)
        if inputStream == nil {
          fatalError("failed to create input stream")
        }
        inputStream!.open()
        
        self.curl.reset()
        var url = "ftp://\(self.hostName)\(self.currentPath)"
        url = url.hasSuffix("/") ? "\(url)\(fileName)" : "\(url)/\(fileName)"
        self.curl.URL = url
        self.setAuthParams()
        self.curl.upload = true
        self.curl.inFileSize = fileSize.integerValue
        self.curl.readFunction = {(buffer, size) in
          return inputStream!.read(buffer, maxLength: size)
        }
        self.curl.noProgress = false
        self.curl.xferInfoFunction = progressCallback
        code = self.curl.perform()
        inputStream!.close()
    }
    if coordinatorError != nil {
      fatalError(coordinatorError!.description)
    }
    return code
  }
  
  func changeDirectory(remotePath: String) -> (CurlCode, [FileListItem]?) {
    let outputStream = NSOutputStream.outputStreamToMemory()
    outputStream.open()
    assert(remotePath.hasPrefix("/"))
    assert(remotePath.hasSuffix("/"))
    self.curl.reset()
    let url = "ftp://\(self.hostName)\(remotePath)"
    self.curl.URL = url
    self.setAuthParams()
    self.curl.writeFunction = {(buffer, size) in
      return outputStream.write(buffer, maxLength: size)
    }
    let code = self.curl.perform()
    if code == CurlCode.OK {
      self.currentPath = remotePath;
      let data = outputStream.propertyForKey(NSStreamDataWrittenToMemoryStreamKey) as! NSData
      let listItems = self.listParser.parse(data)
      return (code, listItems)
    }
    return (code, nil)
  }
  
  func makeDirectory(directoryName: String) -> CurlCode {
    self.curl.reset()
    self.curl.URL = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["MKD \(directoryName)"]
    let code = self.curl.perform()
    return code
  }
  
  func removeDirectory(directoryName: String) -> CurlCode {
    self.curl.reset()
    self.curl.URL = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["RMD \(directoryName)"]
    let code = self.curl.perform()
    return code
  }
  
  func renameFile(oldName: String, newName: String) -> CurlCode {
    self.curl.reset()
    self.curl.URL = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = [
      "RNFR \(oldName)",
      "RNTO \(newName)",
    ]
    let code = self.curl.perform()
    return code
  }
  
  func removeFile(fileName: String) -> CurlCode {
    self.curl.reset()
    self.curl.URL = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["DELE \(fileName)"]
    let code = self.curl.perform()
    return code
  }
  
  func changePermissions(fileName: String, permission: UInt) -> CurlCode {
    let hex = NSString(format: "%3x", permission)
    self.curl.reset()
    self.curl.URL = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["SITE CHMOD \(hex) \(fileName)"]
    let code = self.curl.perform()
    return code
  }
}
