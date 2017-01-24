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

protocol CertificateViewControllerDelegate: class {
  func certificateViewController(_ certificateViewController: CertificateViewController, didFinishWithResult: OpenSSLVerifyResult)
}

class CertificateViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  @IBOutlet weak var tableView: NSTableView!
  @IBOutlet weak var scrollView: NSScrollView!
  var certificateView: CertificateView!
  var certs: [SecCertificate]? {
    didSet {
      uiUpdateRequired = true
    }
  }
  var uiUpdateRequired = true
  weak var delegate: CertificateViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.dataSource = self
    tableView.delegate = self
    certificateView = CertificateView(frame: scrollView.bounds)
    scrollView.documentView = certificateView
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    if uiUpdateRequired {
      if certs != nil && certs!.count > 0 {
        tableView.selectColumnIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        certificateView.setCertificate(certs!.first!)
        certificateView.setDetailsDisclosed(true)
      }
      uiUpdateRequired = false
    }
  }
  
  @IBAction func onOK(_ sender: AnyObject) {
    delegate?.certificateViewController(self, didFinishWithResult: OpenSSLVerifyResult.CONTINUE)
    presenting?.dismissViewController(self)
  }
  
  @IBAction func onCancel(_ sender: AnyObject) {
    delegate?.certificateViewController(self, didFinishWithResult: OpenSSLVerifyResult.STOP)
    presenting?.dismissViewController(self)
  }
  
  func numberOfRows(in tableView: NSTableView) -> Int {
    return self.certs != nil ? self.certs!.count : 0
  }
  
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    if certs == nil {
      return nil
    }
    let cert = certs![row]
    guard let desc = SecCertificateCopyShortDescription(kCFAllocatorDefault, cert, nil) as? String else {
      fatalError()
    }
    let cell = tableView.make(withIdentifier: "certCell", owner: self) as! NSTableCellView
    cell.textField?.stringValue = desc
    return cell
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    let index = tableView.selectedRow
    if index < 0 {
      return
    }
    if let certs = certs {
      certificateView.setCertificate(certs[index])
    }
  }
  
}
