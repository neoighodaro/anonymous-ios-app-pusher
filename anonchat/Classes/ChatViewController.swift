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

    var messages = [JSQMessage]()
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
        postMessage(name: senderId, message: text)
        addMessage(senderId: senderId, name: senderId, text: text)
        self.finishSendingMessage(animated: true)
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

    private func postMessage(name: String, message: String) {
        let params: Parameters = ["sender": name, "text": message]
        hitEndpoint(url: ChatViewController.API_ENDPOINT + "/messages", parameters: params)
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
    
    private func hitEndpoint(url: String, parameters: Parameters) {
        Alamofire.request(url, method: .post, parameters: parameters).validate().responseJSON { response in
            switch response.result {
            case .success:
                self.isBusySendingEvent = false
                // Succeeded, do something
                print("Succeeded")
            case .failure(let error):
                self.isBusySendingEvent = false
                // Failed, do something
                print(error)
            }
        }
    }

    private func addMessage(senderId: String, name: String, text: String) {
        if let message = JSQMessage(senderId: senderId, displayName: name, text: text) {
            messages.append(message)
        }
    }
    
    private func listenForNewMessages() {
        let options = PusherClientOptions(
            host: .cluster("mt1")
        )
        
        pusher = Pusher(key: "efba09906153a581bd31", options: options)
        
        let channel = pusher.subscribe("chatroom")

        channel.bind(eventName: "new_message", callback: { (data: Any?) -> Void in
            if let data = data as? [String: AnyObject] {
                let author = data["sender"] as! String

                if author != self.senderId {
                    let text = data["text"] as! String
                    self.addMessage(senderId: author, name: author, text: text)
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
