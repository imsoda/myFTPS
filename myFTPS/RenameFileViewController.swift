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

protocol RenameFileViewControllerDelegate: class {
  func renameFileViewController(_ renameFileViewController: RenameFileViewController, didFinishWithResult: RenameFileViewControllerResult?)
}

struct RenameFileViewControllerResult {
  var oldFileName = ""
  var newFileName = ""
}

class RenameFileViewController: NSViewController {
  @IBOutlet weak var newFileNameTextField: NSTextField!
  weak var delegate: RenameFileViewControllerDelegate?
  var oldFileName: String = "" {
    didSet {
      uiUpdateRequired = true
    }
  }
  var uiUpdateRequired = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear() {
    if uiUpdateRequired {
      newFileNameTextField.stringValue = oldFileName
      uiUpdateRequired = false
    }
  }
  
  @IBAction func onOK(_ sender: AnyObject) {
    let newFileName = newFileNameTextField.stringValue
    if newFileName.isEmpty {
      let alert = NSAlert()
      alert.messageText = "New file name is empty"
      alert.informativeText = "New file name must not be empty."
      alert.alertStyle = NSAlert.Style.warning
      alert.runModal()
      return
    }
    else if newFileName.range(of: "/") != nil {
      let alert = NSAlert()
      alert.messageText = "Invalid file name"
      alert.informativeText = "File name must not contain '/'."
      alert.alertStyle = NSAlert.Style.warning
      alert.runModal()
      return
    }
    var result = RenameFileViewControllerResult()
    result.oldFileName = oldFileName
    result.newFileName = newFileName
    delegate?.renameFileViewController(self, didFinishWithResult: result)
    presenting?.dismissViewController(self)
  }
  
  @IBAction func onCancel(_ sender: AnyObject) {
    delegate?.renameFileViewController(self, didFinishWithResult: nil)
    presenting?.dismissViewController(self)
  }
}
