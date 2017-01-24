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
  (_ ftpsClient: FTPSClient, _ preverify: OpenSSLPreverify, _ status: OSStatus, _ result: SecTrustResultType, _ certs: [SecCertificate]) -> Void

open class FTPSClient {
  let curl = Curl()
  let openSSLHelper = OpenSSLHelper()
  let listParser = FileListParser()
  let hostName: String
  let userName: String
  let password: String
  var currentPath = "/"
  let semaphore = DispatchSemaphore(value: 1)
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
  
  func certVerify(_ preverify: OpenSSLPreverify, status: OSStatus, result: SecTrustResultType, certs _certs: NSArray) -> OpenSSLVerifyResult {
    var certs = [SecCertificate]()
    for _cert in _certs {
      let cert = _cert as! SecCertificate
      certs.append(cert)
    }
    var sslResult = OpenSSLVerifyResult.STOP
    if self.sslVerificationCallback != nil {
      DispatchQueue.main.async(execute: { () -> Void in
        self.sslVerificationCallback!(self, preverify, status, result, certs)
      })
      let waitTime: Int64 = 250 * Int64(NSEC_PER_MSEC)
      while true {
        let time = DispatchTime.now() + Double(waitTime) / Double(NSEC_PER_SEC)
        let ret = self.semaphore.wait(timeout: time)
        if ret == .success {
          if self.verifyResult != nil {
            sslResult = self.verifyResult!
            self.semaphore.signal()
            break
          }
          else {
            self.semaphore.signal()
            Thread.sleep(forTimeInterval: 0.25)
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
    self.curl.useSSL = CurlUseSSL.all
    self.curl.sslVerifyHost = false
    self.curl.sslVerifyPeer = false
    self.curl.sslCtxFunction = {(curl, sslCtx) -> CurlCode in
      self.openSSLHelper.registerCertVerifyCallback(sslCtx);
      //typedef OpenSSLVerifyResult (^OpenSSLCertVerifyCallback)(OpenSSLPreverify preverify, OSStatus status, SecTrustResultType result, NSArray *certs);
      self.openSSLHelper.certVerifyCallback = {(preverify: OpenSSLPreverify, status: OSStatus, result: SecTrustResultType, certs: [Any]) in
        self.certVerify(preverify, status: status, result: result, certs: certs as NSArray)
      }
      return CurlCode.OK
    }
  }
  
  public typealias ProgressCallback = (_ downloadTotal: Int, _ downloadNow: Int,
    _ uploadTotal: Int, _ uploadNow: Int) -> CurlProgress
  
  open func download(_ remoteFileName: String, localPath: String, progressCallback: @escaping ProgressCallback) -> CurlCode {
    let coordinator = NSFileCoordinator()
    let localURL = URL(fileURLWithPath: localPath)
    var coordinatorError: NSError?
    var code: CurlCode = CurlCode.readError
    coordinator.coordinate(writingItemAt: localURL,
      options: [],
      error: &coordinatorError) { (localURL) -> Void in
        
        let localPath = localURL.path
        let outputStream = OutputStream(toFileAtPath: localPath, append: false)
        if outputStream == nil {
          fatalError("failed to create output stream")
        }
        outputStream!.open()
        self.curl.reset()
        var url = "ftp://\(self.hostName)\(self.currentPath)"
        url = url.hasSuffix("/") ? "\(url)\(remoteFileName)" : "\(url)/\(remoteFileName)"
        self.curl.url = url
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
  
  func upload(localPath: String, progressCallback: @escaping ProgressCallback) -> CurlCode {
    let fileName = (localPath as NSString).lastPathComponent
    let coordinator = NSFileCoordinator()
    let localURL = URL(fileURLWithPath: localPath)
    var coordinatorError: NSError?
    var code: CurlCode = CurlCode.uploadFailed
    coordinator.coordinate(readingItemAt: localURL,
      options: [],
      error: &coordinatorError) { (localURL) -> Void in
        
        let localPath = localURL.path
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: localPath) else {
          fatalError("failed to get file attribute")
        }
        let fileSize = attributes[FileAttributeKey.size] as! NSNumber
        let inputStream = InputStream(fileAtPath: localPath)
        if inputStream == nil {
          fatalError("failed to create input stream")
        }
        inputStream!.open()
        
        self.curl.reset()
        var url = "ftp://\(self.hostName)\(self.currentPath)"
        url = url.hasSuffix("/") ? "\(url)\(fileName)" : "\(url)/\(fileName)"
        self.curl.url = url
        self.setAuthParams()
        self.curl.upload = true
        self.curl.inFileSize = fileSize.intValue
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
  
  func changeDirectory(_ remotePath: String) -> (CurlCode, [FileListItem]?) {
    let outputStream = OutputStream.toMemory()
    outputStream.open()
    assert(remotePath.hasPrefix("/"))
    assert(remotePath.hasSuffix("/"))
    self.curl.reset()
    let url = "ftp://\(self.hostName)\(remotePath)"
    self.curl.url = url
    self.setAuthParams()
    self.curl.writeFunction = {(buffer, size) in
      return outputStream.write(buffer, maxLength: size)
    }
    let code = self.curl.perform()
    if code == CurlCode.OK {
      self.currentPath = remotePath;
      let data = outputStream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data
      let listItems = self.listParser.parse(data)
      return (code, listItems)
    }
    return (code, nil)
  }
  
  func makeDirectory(_ directoryName: String) -> CurlCode {
    self.curl.reset()
    self.curl.url = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["MKD \(directoryName)"]
    let code = self.curl.perform()
    return code
  }
  
  func removeDirectory(_ directoryName: String) -> CurlCode {
    self.curl.reset()
    self.curl.url = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["RMD \(directoryName)"]
    let code = self.curl.perform()
    return code
  }
  
  func renameFile(_ oldName: String, newName: String) -> CurlCode {
    self.curl.reset()
    self.curl.url = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = [
      "RNFR \(oldName)",
      "RNTO \(newName)",
    ]
    let code = self.curl.perform()
    return code
  }
  
  func removeFile(_ fileName: String) -> CurlCode {
    self.curl.reset()
    self.curl.url = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["DELE \(fileName)"]
    let code = self.curl.perform()
    return code
  }
  
  func changePermissions(_ fileName: String, permission: UInt) -> CurlCode {
    let hex = NSString(format: "%3x", permission)
    self.curl.reset()
    self.curl.url = "ftp://\(self.hostName)\(self.currentPath)"
    self.setAuthParams()
    self.curl.noBody = true
    self.curl.postQuote = ["SITE CHMOD \(hex) \(fileName)"]
    let code = self.curl.perform()
    return code
  }
}
