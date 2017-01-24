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

protocol ConnectViewControllerDelegate : class {
  func connectViewController(_ connectViewController: ConnectViewController, didFinishWithResult: ConnectViewControllerResult?)
}

struct ConnectViewControllerResult {
  var hostName = ""
  var userName = ""
  var password = ""
  var path = ""
}

class ConnectViewController: NSViewController {
  
  @IBOutlet weak var hostNameTextField: NSTextField!
  @IBOutlet weak var userNameTextField: NSTextField!
  @IBOutlet weak var passwordTextField: NSSecureTextField!
  @IBOutlet weak var pathTextField: NSTextField!
  
  weak var delegate: ConnectViewControllerDelegate?
  
  var hostName: String = "" {
    didSet {
      uiUpdateRequired = true
    }
  }
  var userName: String = "" {
    didSet {
      uiUpdateRequired = true
    }
  }
  var password: String = "" {
    didSet {
      uiUpdateRequired = true
    }
  }
  var path: String = "/" {
    didSet {
      uiUpdateRequired = true
    }
  }
  var uiUpdateRequired = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewDidAppear() {
    super.viewDidAppear()
    if uiUpdateRequired {
      hostNameTextField.stringValue = hostName
      userNameTextField.stringValue = userName
      passwordTextField.stringValue = password
      pathTextField.stringValue = path
      uiUpdateRequired = false
    }
    
    if hostNameTextField.stringValue.isEmpty {
      hostNameTextField.becomeFirstResponder()
    }
    else if userNameTextField.stringValue.isEmpty {
      userNameTextField.becomeFirstResponder()
    }
    else if passwordTextField.stringValue.isEmpty {
      passwordTextField.becomeFirstResponder()
    }
    else if pathTextField.stringValue.isEmpty {
      pathTextField.becomeFirstResponder()
    }
  }
  
  @IBAction func onOK(_ sender: AnyObject) {
    let hostName = hostNameTextField.stringValue
    if hostName.isEmpty {
      hostNameTextField.becomeFirstResponder()
      return
    }
    let userName = userNameTextField.stringValue
    if userName.isEmpty {
      userNameTextField.becomeFirstResponder()
      return
    }
    let password = passwordTextField.stringValue
    var path = pathTextField.stringValue
    path = NormalizePath(path)
    
    var result = ConnectViewControllerResult()
    result.hostName = hostName
    result.userName = userName
    result.password = password
    result.path = path
    delegate?.connectViewController(self, didFinishWithResult: result)
    presenting?.dismissViewController(self)
  }
  
  @IBAction func onCancel(_ sender: AnyObject) {
    delegate?.connectViewController(self, didFinishWithResult: nil)
    presenting?.dismissViewController(self)
  }
}
