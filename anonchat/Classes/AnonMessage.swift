//
//  AnonMessage.swift
//  anonchat
//
//  Created by Neo Ighodaro on 14/05/2017.
//  Copyright © 2017 CreativityKills Labs. All rights reserved.
//

import UIKit
import JSQMessagesViewController

enum AnonMessageStatus {
    case failed
    case sending
    case sent
    case delivered
}

class AnonMessage: JSQMessage {
    var status : AnonMessageStatus
    var id : Int
    
    public init!(senderId: String, status: AnonMessageStatus, displayName: String, text: String, id: Int) {
        self.status = status
        self.id = id
        super.init(senderId: senderId, senderDisplayName: displayName, date: Date.init(), text: text)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
