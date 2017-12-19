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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


protocol FileListTableViewDragDelegate {
  func fileListTableView(_ fileListTableView: FileListTableView, didDragFiles files: [String])
}

class FileListTableView: NSTableView {
  var dragDelegate: FileListTableViewDragDelegate? = nil
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return NSDragOperation.copy
  }
  
  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    return NSDragOperation.copy
  }
  
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pboard = sender.draggingPasteboard()
    let types = pboard.types?.filter {($0 as NSString) as String == NSPasteboard.PasteboardType.fileURL.rawValue}
    if types?.count > 0 {
      if let files = pboard.propertyList(forType: NSPasteboard.PasteboardType.fileURL) as? [String] {
        dragDelegate?.fileListTableView(self, didDragFiles: files)
        return true
      }
    }
    return false
  }
}
