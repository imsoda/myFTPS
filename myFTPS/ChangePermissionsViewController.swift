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

protocol ChangePermissionsViewControllerDelegate: class {
  func changePermissionsViewController(_ changePermissionsViewController: ChangePermissionsViewController, didFinishWithResult: ChangePermissionsViewControllerResult?)
}

struct ChangePermissionsViewControllerResult {
  var fileName = ""
  var permissions: UInt = 0
}

class ChangePermissionsViewController: NSViewController {
  weak var delegate: ChangePermissionsViewControllerDelegate?
  
  @IBOutlet weak var userReadCheckbox: NSButton!
  @IBOutlet weak var userWriteCheckbox: NSButton!
  @IBOutlet weak var userExecuteCheckbox: NSButton!
  @IBOutlet weak var groupReadCheckbox: NSButton!
  @IBOutlet weak var groupWriteCheckbox: NSButton!
  @IBOutlet weak var groupExecuteCheckbox: NSButton!
  @IBOutlet weak var otherReadCheckbox: NSButton!
  @IBOutlet weak var otherWriteCheckbox: NSButton!
  @IBOutlet weak var otherExecuteCheckbox: NSButton!
  @IBOutlet weak var fileNameLabel: NSTextFieldCell!
  
  var fileListItem: FileListItem? = nil {
    didSet {
      uiUpdateRequired = true
    }
  }
  var uiUpdateRequired = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    if uiUpdateRequired {
      self.fileNameLabel.stringValue = fileListItem!.fileName
      
      let user = fileListItem!.userPermissions as NSString
      let group = fileListItem!.groupPermissions as NSString
      let other = fileListItem!.otherPermissions as NSString
      
      if user.length == 3 {
        self.userReadCheckbox.state = user.substring(with: NSRange(location: 0, length: 1)) == "r" ? NSOnState : NSOffState
        self.userWriteCheckbox.state = user.substring(with: NSRange(location: 1, length: 1)) == "w" ? NSOnState : NSOffState
        self.userExecuteCheckbox.state = user.substring(with: NSRange(location: 2, length: 1)) == "x" ? NSOnState : NSOffState
      }
      else {
        self.userReadCheckbox.state = NSOffState
        self.userWriteCheckbox.state = NSOffState
        self.userExecuteCheckbox.state = NSOffState
      }
      
      if group.length == 3 {
        self.groupReadCheckbox.state = group.substring(with: NSRange(location: 0, length: 1)) == "r" ? NSOnState : NSOffState
        self.groupWriteCheckbox.state = group.substring(with: NSRange(location: 1, length: 1)) == "w" ? NSOnState : NSOffState
        self.groupExecuteCheckbox.state = group.substring(with: NSRange(location: 2, length: 1)) == "x" ? NSOnState : NSOffState
      }
      else {
        self.groupReadCheckbox.state = NSOffState
        self.groupWriteCheckbox.state = NSOffState
        self.groupExecuteCheckbox.state = NSOffState
      }
      
      if other.length == 3 {
        self.otherReadCheckbox.state = other.substring(with: NSRange(location: 0, length: 1)) == "r" ? NSOnState : NSOffState
        self.otherWriteCheckbox.state = other.substring(with: NSRange(location: 1, length: 1)) == "w" ? NSOnState : NSOffState
        self.otherExecuteCheckbox.state = other.substring(with: NSRange(location: 2, length: 1)) == "x" ? NSOnState : NSOffState
      }
      else {
        self.otherReadCheckbox.state = NSOffState
        self.otherWriteCheckbox.state = NSOffState
        self.otherExecuteCheckbox.state = NSOffState
      }
      uiUpdateRequired = false
    }
  }
  
  @IBAction func onOK(_ sender: AnyObject) {
    var user: UInt = 0
    if self.userReadCheckbox.state == NSOnState {
      user += 4
    }
    if self.userWriteCheckbox.state == NSOnState {
      user += 2
    }
    if self.userExecuteCheckbox.state == NSOnState {
      user += 1
    }
    
    var group: UInt = 0
    if self.groupReadCheckbox.state == NSOnState {
      group += 4
    }
    if self.groupWriteCheckbox.state == NSOnState {
      group += 2
    }
    if self.groupExecuteCheckbox.state == NSOnState {
      group += 1
    }
    
    var other: UInt = 0
    if self.otherReadCheckbox.state == NSOnState {
      other += 4
    }
    if self.otherWriteCheckbox.state == NSOnState {
      other += 2
    }
    if self.otherExecuteCheckbox.state == NSOnState {
      other += 1
    }
    var result = ChangePermissionsViewControllerResult()
    result.fileName = fileListItem!.fileName
    result.permissions = (user * (16 * 16) + group * 16 + other) as UInt

    delegate?.changePermissionsViewController(self, didFinishWithResult: result)
    presenting?.dismissViewController(self)
  }
  
  @IBAction func onCancel(_ sender: AnyObject) {
    delegate?.changePermissionsViewController(self, didFinishWithResult: nil)
    presenting?.dismissViewController(self)
  }
}
