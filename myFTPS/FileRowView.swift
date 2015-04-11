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

class FileRowView : NSTableRowView {
  override func drawSelectionInRect(dirtyRect: NSRect) {
    if self.selectionHighlightStyle != NSTableViewSelectionHighlightStyle.None {
//      let selectionRect = NSInsetRect(self.bounds, 0.5, 0.5)
      let selectionRect = NSMakeRect(1.0, 2.0, self.bounds.size.width - 2.0, self.bounds.size.height - 2.0)
      NSColor(calibratedWhite: 0.55, alpha: 1.0).setStroke()
      NSColor(calibratedWhite: 0.82, alpha: 1.0).setFill()
      let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
      selectionPath.fill()
      selectionPath.stroke()
    }
  }
}
