//
//  WelcomeViewController.swift
//  anonchat
//
//  Created by Neo Ighodaro on 08/05/2017.
//  Copyright © 2017 CreativityKills Labs. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {
    var username : String = ""

    @IBOutlet weak var loginBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }


    @IBAction func editingUsername(_ sender: UITextField) {
        if sender.hasText && (sender.text?.characters.count)! >= 3 && noCaps(text: sender.text!) && noSpaces(text: sender.text!) {
            loginBtn.isEnabled = true
        } else {
            loginBtn.isEnabled = false
        }
        
        username = sender.text!
    }
    
    private func noSpaces(text: String) -> Bool {
        let range = text.rangeOfCharacter(from: .whitespaces)
        
        return range == nil
    }
    
    private func noCaps(text : String) -> Bool {
        let capitalLetterRegEx  = ".*[A-Z]+.*"
        let texttest = NSPredicate(format:"SELF MATCHES %@", capitalLetterRegEx)
        let capitalresult = texttest.evaluate(with: text)
        return capitalresult == false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.childViewControllers.forEach({ (viewController) in
            let classname = (NSStringFromClass(viewController.classForCoder).components(separatedBy: ".").last!)
            if classname == "ChatViewController" {
                let controller = viewController as? ChatViewController
                controller?.setSenderId(name: self.username)
            }
        })
    }
}
