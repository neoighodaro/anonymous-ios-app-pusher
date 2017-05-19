//
//  ChatViewController.swift
//  anonchat
//
//  Created by Neo Ighodaro on 09/05/2017.
//  Copyright © 2017 CreativityKills Labs. All rights reserved.
//

import UIKit
import Alamofire
import PusherSwift
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
    static let API_ENDPOINT = "http://localhost:4000";

    var messages = [AnonMessage]()
    var pusher: Pusher!
    
    var isBusySendingEvent : Bool = false

    var incomingBubble: JSQMessagesBubbleImage!
    var outgoingBubble: JSQMessagesBubbleImage!
    
    var isTypingEventLifetime = Timer()

    override func viewDidLoad() {
        super.viewDidLoad()

        inputToolbar.contentView.leftBarButtonItem = nil

        incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
        outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())

        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero

        automaticallyScrollsToMostRecentMessage = true

        collectionView?.reloadData()
        collectionView?.layoutIfNeeded()

        listenForNewMessages()
        
        isTypingEventLifetime = Timer.scheduledTimer(timeInterval: 2.0,
                                                     target: self,
                                                     selector: #selector(isTypingEventExpireAction),
                                                     userInfo: nil,
                                                     repeats: true)
        
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        if !isAnOutgoingMessage(indexPath) {
            return nil
        }
        
        let message = messages[indexPath.row]

        switch (message.status) {
        case .sending:
            return NSAttributedString(string: "Sending...")
        case .sent:
            return NSAttributedString(string: "Sent!")
        case .delivered:
            return NSAttributedString(string: "Delivered")
        case .failed:
            return NSAttributedString(string: "Failed")
        }
    }
    
    private func isAnOutgoingMessage(_ indexPath: IndexPath!) -> Bool {
        return messages[indexPath.row].senderId == senderId
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAt indexPath: IndexPath!) -> CGFloat {
        return CGFloat(15.0)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubble
        } else {
            return incomingBubble
        }
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }

    override func didPressSend(_ button: UIButton, withMessageText text: String, senderId: String, senderDisplayName: String, date: Date) {
        let message = addMessage(senderId: senderId, name: senderId, text: text) as! AnonMessage

        postMessage(message: message)
        
        finishSendingMessage(animated: true)
    }
    
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        sendIsTypingEvent(forUser: senderId)
    }

    public func setSenderId(name: String) {
        senderId = name
        senderDisplayName = senderId
    }
    
    public func isTypingEventExpireAction() {
        navigationItem.title = "AnonChat"
    }
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }

    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())
    }

    private func postMessage(message: AnonMessage) {
        let params: Parameters = ["sender": message.senderId, "text": message.text]
        hitEndpoint(url: ChatViewController.API_ENDPOINT + "/messages", parameters: params, message: message)
    }
    
    private func sendIsTypingEvent(forUser: String) {
        if isBusySendingEvent == false {
            isBusySendingEvent = true
            let params: Parameters = ["sender": forUser]
            hitEndpoint(url: ChatViewController.API_ENDPOINT + "/typing", parameters: params)
        } else {
            print("Still sending something")
        }
    }
    
    private func hitEndpoint(url: String, parameters: Parameters, message: AnonMessage? = nil) {
        Alamofire.request(url, method: .post, parameters: parameters).validate().responseJSON { response in
            switch response.result {
            case .success:
                self.isBusySendingEvent = false

                if message != nil {
                    message?.status = .delivered
                    self.collectionView.reloadData()
                }
                
            case .failure(let error):
                self.isBusySendingEvent = false
                print(error)
            }
        }
    }

    private func addMessage(senderId: String, name: String, text: String) -> Any? {
        let leStatus = senderId == self.senderId
            ? AnonMessageStatus.sending
            : AnonMessageStatus.delivered
        
        let message = AnonMessage(senderId: senderId, status: leStatus, displayName: name, text: text, id: messages.count)
        
        if (message != nil) {
            messages.append(message as AnonMessage!)
        }
        
        return message
    }
    
    private func listenForNewMessages() {
        let options = PusherClientOptions(
            host: .cluster("mt1")
        )
        
        pusher = Pusher(key: "4a2632feed06a8ef84f9", options: options)
        
        let channel = pusher.subscribe("chatroom")

        channel.bind(eventName: "new_message", callback: { (data: Any?) -> Void in
            if let data = data as? [String: AnyObject] {
                let author = data["sender"] as! String

                if author != self.senderId {
                    let text = data["text"] as! String
                    
                    let message = self.addMessage(senderId: author, name: author, text: text) as! AnonMessage?
                    message?.status = .delivered
                    
                    self.finishReceivingMessage(animated: true)
                }
            }
        })

        channel.bind(eventName: "user_typing", callback: { (data: Any?) -> Void in
            if let data = data as? [String: AnyObject] {
                let author = data["sender"] as! String
                if author != self.senderId {
                    let text = data["text"] as! String
                    self.navigationItem.title = text
                }
            }
        })
        
        pusher.connect()
    }
}
