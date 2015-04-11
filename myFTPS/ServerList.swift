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

class ServerListItem : NSObject, NSCoding, Printable {
  var itemName = ""
  var hostName = ""
  var userName = ""
  var path = "/"
  
  override init() {}
  
  required init(coder aDecoder: NSCoder) {
    let itemName = aDecoder.decodeObjectOfClass(NSString.self, forKey: "itemName") as? String
    self.itemName = itemName != nil ? itemName! : "itemName\(arc4random())"
    
    let hostName = aDecoder.decodeObjectOfClass(NSString.self, forKey: "hostName") as? String
    self.hostName = hostName != nil ? hostName! : ""
    
    let userName = aDecoder.decodeObjectOfClass(NSString.self, forKey: "userName") as? String
    self.userName = userName != nil ? userName! : ""
    
    let path = aDecoder.decodeObjectOfClass(NSString.self, forKey: "path") as? String
    self.path = path != nil ? path! : "/"
  }
  
  func encodeWithCoder(aCoder: NSCoder) {
    
    aCoder.encodeObject(itemName, forKey: "itemName")
    aCoder.encodeObject(hostName, forKey: "hostName")
    aCoder.encodeObject(userName, forKey: "userName")
    aCoder.encodeObject(path, forKey: "path")
  }
  override var description: String { get {
    return "{itemName=\(itemName),hostName=\(hostName),userName=\(userName),path=\(path)}"
    }
  }
}

class ServerList {
  let KEY = "com.cx5software.myFTPS.serverList"
  var list = [ServerListItem]()
  
  init() {
    list = loadList()
  }

  func indexOfItem(#hostName: String, userName: String, path: String) -> Int {
    for i in 0 ..< list.count {
      if list[i].hostName == hostName && list[i].userName == userName && list[i].path == path {
        return i
      }
    }
    return -1
  }
  
  func indexOfItem(#itemName: String) -> Int {
    for i in 0 ..< list.count {
      if list[i].itemName == itemName {
        return i
      }
    }
    return -1
  }
  
  func add(item: ServerListItem) -> Int {
    let index = indexOfItem(itemName: item.itemName)
    assert(index < 0)
    list.append(item)
    list.sort { (item1, item2) -> Bool in
      return item1.itemName < item2.itemName
    }
    storeList(list)
    return indexOfItem(itemName: item.itemName)
  }
  
  func remove(item: ServerListItem) {
    let index = indexOfItem(itemName: item.itemName)
    assert(index >= 0)
    list.removeAtIndex(index)
    storeList(list)
  }
  
  func rename(#oldItemName: String, newItemName: String) {
    let index = indexOfItem(itemName: oldItemName)
    assert(index >= 0)
    assert(indexOfItem(itemName: newItemName) < 0)
    var item = list[index]
    item.itemName = newItemName
    list.sort { (item1, item2) -> Bool in
      return item1.itemName < item2.itemName
    }
    storeList(list)
  }
  
  subscript(index: Int) -> ServerListItem {
    get {
      return list[index]
    }
    set {
      list[index] = newValue
    }
  }
  
  var count: Int {
    return list.count
  }
  
  func storeList(list: [ServerListItem]) {
    var data = NSKeyedArchiver.archivedDataWithRootObject(list)
    let userDefault = NSUserDefaults.standardUserDefaults()
    userDefault.setObject(data, forKey: KEY)
  }
  
  func loadList() -> [ServerListItem] {
    let userDefault = NSUserDefaults.standardUserDefaults()
    if userDefault.objectForKey(KEY) != nil {
      var data = userDefault.objectForKey(KEY) as? NSData
      if data != nil {
        let list = NSKeyedUnarchiver.unarchiveObjectWithData(data!) as? [ServerListItem]
        if list != nil {
          return list!
        }
      }
    }
    return createEmptyList()
  }
  
  func createEmptyList() -> [ServerListItem] {
    let list = [ServerListItem]()
    storeList(list)
    return list
  }
}
