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

class FileListParser {
  var unixTime: NSRegularExpression!
  var unixYear: NSRegularExpression!
  var dosFile: NSRegularExpression!
  var dosDir: NSRegularExpression!
  var exclusionFileNames = [String]()
  
  init() {
    var unixTimeStr = "^"
    // dir
    unixTimeStr += "([\\-dbclps])"
    // user permission
    unixTimeStr += "([\\-r][\\-w][\\-xstST])"
    // group permission
    unixTimeStr += "([\\-r][\\-w][\\-xstST])"
    // other permission
    unixTimeStr += "([\\-r][\\-w][\\-xstST])\\s+"
    // filecode
    unixTimeStr += "(\\d+)\\s+"
    // owner
    unixTimeStr += "(\\w+)\\s+"
    // group
    unixTimeStr += "(\\w+)\\s+"
    // size
    unixTimeStr += "(\\d+)\\s+"
    // month
    unixTimeStr += "(\\w{3})\\s+"
    // day
    unixTimeStr += "(\\d{1,2})\\s+"
    // hour
    unixTimeStr += "(\\d{1,2}):"
    // minute
    unixTimeStr += "(\\d{2})\\s+"
    // name
    unixTimeStr += "(.+)$"
    self.unixTime = try! NSRegularExpression(pattern: unixTimeStr, options: [])
    
    assert(self.unixTime != nil)
    
    var unixYearStr = "^"
    // dir
    unixYearStr += "([\\-dbclps])"
    // user permission
    unixYearStr += "([\\-r][\\-w][\\-xstST])"
    // group permission
    unixYearStr += "([\\-r][\\-w][\\-xstST])"
    // other permission
    unixYearStr += "([\\-r][\\-w][\\-xstST])\\s+"
    // filecode
    unixYearStr += "(\\d+)\\s+"
    // owner
    unixYearStr += "(\\w+)\\s+"
    // group
    unixYearStr += "(\\w+)\\s+"
    // size
    unixYearStr += "(\\d+)\\s+"
    // month
    unixYearStr += "(\\w{3})\\s+"
    // day
    unixYearStr += "(\\d{1,2})\\s+"
    // year
    unixYearStr += "(\\d{4})\\s+"
    // name
    unixYearStr += "(.+)$"
    self.unixYear = try! NSRegularExpression(pattern:unixYearStr, options: [])
    assert(self.unixYear != nil)
    
    var dosFileStr = "^"
    // month
    dosFileStr += "(\\d{2})-"
    // day
    dosFileStr += "(\\d{2})-"
    // year
    dosFileStr += "(\\d{2})\\s+"
    // hour
    dosFileStr += "(\\d{2}):"
    // minute
    dosFileStr += "(\\d{2})"
    // am/pm
    dosFileStr += "(AM|PM)\\s+"
    // size
    dosFileStr += "(\\d+)\\s+"
    // name
    dosFileStr += "(.+)$"
    self.dosFile = try! NSRegularExpression(pattern:dosFileStr, options: [])
    assert(self.dosFile != nil)
    
    var dosDirStr = "^"
    // month
    dosDirStr += "(\\d{2})-"
    // day
    dosDirStr += "(\\d{2})-"
    // year
    dosDirStr += "(\\d{2})\\s+"
    // hour
    dosDirStr += "(\\d{2}):"
    // minute
    dosDirStr += "(\\d{2})"
    // am/pm
    dosDirStr += "(AM|PM)\\s+"
    // <DIR>
    dosDirStr += "\\<DIR\\>\\s+"
    // name
    dosDirStr += "(.+)$"
    self.dosDir = try! NSRegularExpression(pattern:dosDirStr, options: [])
    assert(self.dosDir != nil)
  }
  
  func isExclusionFileName(_ item: FileListItem) -> Bool {
    for exclusionFileName in exclusionFileNames {
      if item.fileName == exclusionFileName {
        return true
      }
    }
    return false
  }
  
  func parseUnixTime(result: NSTextCheckingResult, line: String) -> FileListItem {
    precondition(result.numberOfRanges == 14, "invalid")
    let nsline = line as NSString
    var item = FileListItem()
    // dir
    item.directory = nsline.substring(with: result.rangeAt(1))
    // user permission
    item.userPermissions = nsline.substring(with: result.rangeAt(2))
    // group permission
    item.groupPermissions = nsline.substring(with: result.rangeAt(3))
    // other permission
    item.otherPermissions = nsline.substring(with: result.rangeAt(4))
    // owner
    item.owner = nsline.substring(with: result.rangeAt(6))
    // group
    item.group = nsline.substring(with: result.rangeAt(7))
    // size
    let fileSize: NSString = nsline.substring(with: result.rangeAt(8)) as NSString
    item.fileSize = fileSize.integerValue
    
    let month = nsline.substring(with: result.rangeAt(9))
    let day = nsline.substring(with: result.rangeAt(10))
    let hour = nsline.substring(with: result.rangeAt(11))
    let minute = nsline.substring(with: result.rangeAt(12))
    item.date = "\(month) \(day) \(hour):\(minute)"
    
    item.fileName = nsline.substring(with: result.rangeAt(13))
    return item;
  }
  
  func parseUnixYear(result: NSTextCheckingResult, line: String) -> FileListItem {
    precondition(result.numberOfRanges == 13, "invalid")
    let nsline = line as NSString
    var item = FileListItem()
    // dir
    item.directory = nsline.substring(with: result.rangeAt(1))
    // user permission
    item.userPermissions = nsline.substring(with: result.rangeAt(2))
    // group permission
    item.groupPermissions = nsline.substring(with: result.rangeAt(3))
    // other permission
    item.otherPermissions = nsline.substring(with: result.rangeAt(4))
    // owner
    item.owner = nsline.substring(with: result.rangeAt(6))
    // group
    item.group = nsline.substring(with: result.rangeAt(7))
    // size
    let fileSize: NSString = nsline.substring(with: result.rangeAt(8)) as NSString
    item.fileSize = fileSize.integerValue

    let month = nsline.substring(with: result.rangeAt(9))
    let day = nsline.substring(with: result.rangeAt(10))
    let year = nsline.substring(with: result.rangeAt(11))
    item.date = "\(month) \(day) \(year)"

    item.fileName = nsline.substring(with: result.rangeAt(12))
    return item;
  }

  func parseDOSFile(_ result: NSTextCheckingResult, line: String) -> FileListItem {
    precondition(result.numberOfRanges == 9, "invalid")
    let nsline = line as NSString
    var item = FileListItem()
    item.directory = "-"
    let month = nsline.substring(with: result.rangeAt(1))
    let day = nsline.substring(with: result.rangeAt(2))
    let year = nsline.substring(with: result.rangeAt(3))
    let hour = nsline.substring(with: result.rangeAt(4))
    let minute = nsline.substring(with: result.rangeAt(5))
    let ampm = nsline.substring(with: result.rangeAt(6))
    item.date = "\(month)-\(day)-\(year) \(hour):\(minute)\(ampm)"
  
    let fileSize: NSString = nsline.substring(with: result.rangeAt(7)) as NSString
    item.fileSize = fileSize.integerValue
  
    item.fileName = nsline.substring(with: result.rangeAt(8))
    return item
  }

  func parseDOSDir(_ result: NSTextCheckingResult, line: String) -> FileListItem {
    precondition(result.numberOfRanges == 8, "invalid");
    let nsline = line as NSString
    var item = FileListItem()
    item.directory = "d"
    let month = nsline.substring(with: result.rangeAt(1))
    let day = nsline.substring(with: result.rangeAt(2))
    let year = nsline.substring(with: result.rangeAt(3))
    let hour = nsline.substring(with: result.rangeAt(4))
    let minute = nsline.substring(with: result.rangeAt(5))
    let ampm = nsline.substring(with: result.rangeAt(6))
    item.date = "\(month)-\(day)-\(year) \(hour):\(minute)\(ampm)"
  
    item.fileSize = 0;
  
    item.fileName = nsline.substring(with: result.rangeAt(7))
    return item
  }

  func parse(_ data: Data) -> [FileListItem] {
    var listResponse = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
    if listResponse == nil {
      listResponse = NSString(data: data, encoding: String.Encoding.shiftJIS.rawValue)
    }
    if listResponse == nil {
      return []
    }
    
    let lines = listResponse!.components(separatedBy: CharacterSet.newlines)
    if lines.count == 0 {
      return []
    }
    
    var items = [FileListItem]()
    for line in lines {
      if line.isEmpty {
        continue
      }
      let range = NSMakeRange(0, line.utf16.count)
      if let result = unixTime.firstMatch(in: line, options: [], range: range) {
        let item = parseUnixTime(result: result, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      if let result = unixYear.firstMatch(in: line, options: [], range: range) {
        let item = parseUnixYear(result: result, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      if let result = dosFile.firstMatch(in: line, options: [], range: range) {
        let item = parseDOSFile(result, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      if let result = dosDir.firstMatch(in: line, options: [], range: range) {
        let item = parseDOSDir(result, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      Swift.print("WARN: could not parse line: \(line)")
    }
    return items
  }
}
