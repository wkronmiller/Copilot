//
//  ScannerViewController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/22/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit
import AVKit
import Jukebox

class ScannerCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    func setScanner(scanner: Scanner) {
        DispatchQueue.main.async {
            self.title.text = scanner.name
        }
        //TODO
        
    }
}

class ScannerViewController: UITableViewController {
    private static let scanners = Scanners()
    private var player: AVPlayer? = nil
    private var selected: IndexPath? = nil
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return ScannerViewController.scanners.getScanners().count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scannerCell", for: indexPath) as! ScannerCell
        NSLog("Created scanner cell for path \(indexPath)")
        cell.setScanner(scanner: ScannerViewController.scanners.getScanners()[indexPath.row])
        return cell
    }
    
    private func clearPlayer() {
        if let existing = self.player {
            existing.pause()
            existing.cancelPendingPrerolls()
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        self.player = nil
        self.selected = nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.selected == indexPath {
            self.tableView(tableView, didDeselectRowAt: indexPath)
            return
        }
        self.clearPlayer()
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let scanner = ScannerViewController.scanners.getScanners()[indexPath.row]
        self.player = AVPlayer(url: scanner.url)
        self.player!.play()
        self.selected = indexPath
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.clearPlayer()
    }

}
