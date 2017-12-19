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

class ServerListItem : NSObject, NSCoding {
  var itemName = ""
  var hostName = ""
  var userName = ""
  var path = "/"
  
  override init() {}
  
  required init(coder aDecoder: NSCoder) {
    if let itemName = aDecoder.decodeObject(of: NSString.self, forKey: "itemName") as String? {
      self.itemName = itemName
    } else {
      self.itemName = "itemName\(arc4random())"
    }
    
    if let hostName = aDecoder.decodeObject(of: NSString.self, forKey: "hostName") as String? {
      self.hostName = hostName
    } else {
      self.hostName = ""
    }
    
    if let userName = aDecoder.decodeObject(of: NSString.self, forKey: "userName") as String? {
      self.userName = userName
    } else {
      self.userName = ""
    }
    
    if let path = aDecoder.decodeObject(of: NSString.self, forKey: "path") as String? {
      self.path = path
    } else {
      self.path = "/"
    }
  }
  
  func encode(with aCoder: NSCoder) {
    
    aCoder.encode(itemName, forKey: "itemName")
    aCoder.encode(hostName, forKey: "hostName")
    aCoder.encode(userName, forKey: "userName")
    aCoder.encode(path, forKey: "path")
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

  func indexOfItem(_ hostName: String, _ userName: String, path: String) -> Int {
    for i in 0 ..< list.count {
      if list[i].hostName == hostName && list[i].userName == userName && list[i].path == path {
        return i
      }
    }
    return -1
  }
  
  func indexOf(itemName: String) -> Int {
    for i in 0 ..< list.count {
      if list[i].itemName == itemName {
        return i
      }
    }
    return -1
  }
  
  func add(_ item: ServerListItem) -> Int {
    let index = indexOf(itemName: item.itemName)
    assert(index < 0)
    list.append(item)
    list.sort { (item1, item2) -> Bool in
      return item1.itemName < item2.itemName
    }
    storeList(list)
    return indexOf(itemName: item.itemName)
  }
  
  func remove(_ item: ServerListItem) {
    let index = indexOf(itemName: item.itemName)
    assert(index >= 0)
    list.remove(at: index)
    storeList(list)
  }
  
  func rename(oldItemName: String, newItemName: String) {
    let index = indexOf(itemName: oldItemName)
    assert(index >= 0)
    assert(indexOf(itemName: newItemName) < 0)
    let item = list[index]
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
  
  func storeList(_ list: [ServerListItem]) {
    let data = NSKeyedArchiver.archivedData(withRootObject: list)
    let userDefault = UserDefaults.standard
    userDefault.set(data, forKey: KEY)
  }
  
  func loadList() -> [ServerListItem] {
    let userDefault = UserDefaults.standard
    if userDefault.object(forKey: KEY) != nil {
      let data = userDefault.object(forKey: KEY) as? Data
      if data != nil {
        let list = NSKeyedUnarchiver.unarchiveObject(with: data!) as? [ServerListItem]
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
