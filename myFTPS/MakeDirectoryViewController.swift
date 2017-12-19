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

protocol MakeDirectoryViewControllerDelegate : class {
  func makeDirectoryViewController(_ makeDirectoryViewController: MakeDirectoryViewController,
    didFinishWithResult: MakeDirectoryViewControllerResult?)
}

struct MakeDirectoryViewControllerResult {
  var directoryName = ""
}

class MakeDirectoryViewController: NSViewController {
  @IBOutlet weak var directoryNameTextField: NSTextField!
  
  weak var delegate: MakeDirectoryViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  @IBAction func onOK(_ sender: AnyObject) {
    let directoryName = self.directoryNameTextField.stringValue as NSString
    if directoryName.length == 0 {
      let alert = NSAlert()
      alert.messageText = "Directory name is empty"
      alert.informativeText = "Directory name must not be empty."
      alert.alertStyle = NSAlert.Style.warning
      alert.runModal()
      return
    }
    else if directoryName.range(of: "/").location != NSNotFound {
      let alert = NSAlert()
      alert.messageText = "Invalid directory name"
      alert.informativeText = "Directory name must not contain '/'."
      alert.alertStyle = NSAlert.Style.warning
      alert.runModal()
      return
    }
    var result = MakeDirectoryViewControllerResult()
    result.directoryName = directoryNameTextField.stringValue
    delegate?.makeDirectoryViewController(self, didFinishWithResult: result)
    presenting?.dismissViewController(self)
  }
  
  @IBAction func onCancel(_ sender: AnyObject) {
    delegate?.makeDirectoryViewController(self, didFinishWithResult: nil)
    presenting?.dismissViewController(self)
  }
}
