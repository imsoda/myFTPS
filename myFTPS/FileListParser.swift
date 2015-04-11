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
    self.unixTime = NSRegularExpression(pattern: unixTimeStr, options: NSRegularExpressionOptions(0), error: nil)
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
    self.unixYear = NSRegularExpression(pattern:unixYearStr, options: NSRegularExpressionOptions(0), error: nil)
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
    self.dosFile = NSRegularExpression(pattern:dosFileStr, options: NSRegularExpressionOptions(0), error: nil)
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
    self.dosDir = NSRegularExpression(pattern:dosDirStr, options: NSRegularExpressionOptions(0), error: nil)
    assert(self.dosDir != nil)
  }
  
  func isExclusionFileName(item: FileListItem) -> Bool {
    for exclusionFileName in exclusionFileNames {
      if item.fileName == exclusionFileName {
        return true
      }
    }
    return false
  }
  
  func parseUnixTime(result: NSTextCheckingResult, line: NSString) -> FileListItem {
    assert(result.numberOfRanges == 14, "invalid");
    var item = FileListItem()
    // dir
    item.directory = line.substringWithRange(result.rangeAtIndex(1))
    // user permission
    item.userPermissions = line.substringWithRange(result.rangeAtIndex(2))
    // group permission
    item.groupPermissions = line.substringWithRange(result.rangeAtIndex(3))
    // other permission
    item.otherPermissions = line.substringWithRange(result.rangeAtIndex(4))
    // owner
    item.owner = line.substringWithRange(result.rangeAtIndex(6))
    // group
    item.group = line.substringWithRange(result.rangeAtIndex(7))
    // size
    let fileSize: NSString = line.substringWithRange(result.rangeAtIndex(8))
    item.fileSize = fileSize.integerValue
    
    let month = line.substringWithRange(result.rangeAtIndex(9))
    let day = line.substringWithRange(result.rangeAtIndex(10))
    let hour = line.substringWithRange(result.rangeAtIndex(11))
    let minute = line.substringWithRange(result.rangeAtIndex(12))
    item.date = "\(month) \(day) \(hour):\(minute)"
    
    item.fileName = line.substringWithRange(result.rangeAtIndex(13))
    return item;
  }
  
  func parseUnixYear(result: NSTextCheckingResult, line: NSString) -> FileListItem {
    assert(result.numberOfRanges == 13, "invalid")
    var item = FileListItem()
    // dir
    item.directory = line.substringWithRange(result.rangeAtIndex(1))
    // user permission
    item.userPermissions = line.substringWithRange(result.rangeAtIndex(2))
    // group permission
    item.groupPermissions = line.substringWithRange(result.rangeAtIndex(3))
    // other permission
    item.otherPermissions = line.substringWithRange(result.rangeAtIndex(4))
    // owner
    item.owner = line.substringWithRange(result.rangeAtIndex(6))
    // group
    item.group = line.substringWithRange(result.rangeAtIndex(7))
    // size
    let fileSize: NSString = line.substringWithRange(result.rangeAtIndex(8))
    item.fileSize = fileSize.integerValue

    let month = line.substringWithRange(result.rangeAtIndex(9))
    let day = line.substringWithRange(result.rangeAtIndex(10))
    let year = line.substringWithRange(result.rangeAtIndex(11))
    item.date = "\(month) \(day) \(year)"

    item.fileName = line.substringWithRange(result.rangeAtIndex(12))
    return item;
  }

  func parseDOSFile(result: NSTextCheckingResult, line: NSString) -> FileListItem {
    assert(result.numberOfRanges == 9, "invalid")
    var item = FileListItem()
    item.directory = "-"
    let month = line.substringWithRange(result.rangeAtIndex(1))
    let day = line.substringWithRange(result.rangeAtIndex(2))
    let year = line.substringWithRange(result.rangeAtIndex(3))
    let hour = line.substringWithRange(result.rangeAtIndex(4))
    let minute = line.substringWithRange(result.rangeAtIndex(5))
    let ampm = line.substringWithRange(result.rangeAtIndex(6))
    item.date = "\(month)-\(day)-\(year) \(hour):\(minute)\(ampm)"
  
    let fileSize: NSString = line.substringWithRange(result.rangeAtIndex(7))
    item.fileSize = fileSize.integerValue
  
    item.fileName = line.substringWithRange(result.rangeAtIndex(8))
    return item
  }

  func parseDOSDir(result: NSTextCheckingResult, line: NSString) -> FileListItem {
    assert(result.numberOfRanges == 8, "invalid");
    var item = FileListItem()
    item.directory = "d"
    let month = line.substringWithRange(result.rangeAtIndex(1))
    let day = line.substringWithRange(result.rangeAtIndex(2))
    let year = line.substringWithRange(result.rangeAtIndex(3))
    let hour = line.substringWithRange(result.rangeAtIndex(4))
    let minute = line.substringWithRange(result.rangeAtIndex(5))
    let ampm = line.substringWithRange(result.rangeAtIndex(6))
    item.date = "\(month)-\(day)-\(year) \(hour):\(minute)\(ampm)"
  
    item.fileSize = 0;
  
    item.fileName = line.substringWithRange(result.rangeAtIndex(7))
    return item
  }

  func parse(data: NSData) -> [FileListItem] {
    var listResponse = NSString(data: data, encoding: NSUTF8StringEncoding)
    if listResponse == nil {
      var listResponse = NSString(data: data, encoding: NSShiftJISStringEncoding)
    }
    if listResponse == nil {
      return []
    }
    
    let lines = listResponse!.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()) as! [NSString]
    if lines.count == 0 {
      return []
    }
    
    var items = [FileListItem]()
    for line in lines {
      if line.length == 0 {
        continue
      }
      var range = NSMakeRange(0, line.length)
      var result = unixTime.firstMatchInString(line as String, options: NSMatchingOptions(0), range: range)
      if result != nil {
        let item = parseUnixTime(result!, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      result = unixYear.firstMatchInString(line as String, options: NSMatchingOptions(0), range: range)
      if result != nil {
        let item = parseUnixYear(result!, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      result = dosFile.firstMatchInString(line as String, options: NSMatchingOptions(0), range: range)
      if result != nil {
        let item = parseDOSFile(result!, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      result = dosDir.firstMatchInString(line as String, options: NSMatchingOptions(0), range: range)
      if result != nil {
        let item = parseDOSDir(result!, line: line)
        if isExclusionFileName(item) == false {
          items.append(item)
        }
        continue
      }
      println("WARN: could not parse line: \(line)")
    }
    return items
  }
}
