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
    var pusher : Pusher!

    var incomingBubble: JSQMessagesBubbleImage!
    var outgoingBubble: JSQMessagesBubbleImage!

    override func viewDidLoad() {
        super.viewDidLoad()

        let n = Int(arc4random_uniform(1000))

        senderId = "anonymous" + String(n)
        senderDisplayName = senderId

        inputToolbar.contentView.leftBarButtonItem = nil

        incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
        outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())

        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero

        automaticallyScrollsToMostRecentMessage = true

        collectionView?.reloadData()
        collectionView?.layoutIfNeeded()

        listenForNewMessages()
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

        Alamofire.request(ChatViewController.API_ENDPOINT + "/messages", method: .post, parameters: params).validate().responseJSON { response in
            switch response.result {

            case .success:
                // Succeeded, do something
                print("Succeeded")
            case .failure(let error):
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
            host: .cluster("PUSHER_CLUSTER")
        )

        pusher = Pusher(key: "PUSHER_KEY", options: options)

        let channel = pusher.subscribe("chatroom")
        let _ = channel.bind(eventName: "new_message", callback: { (data: Any?) -> Void in

            if let data = data as? [String: AnyObject] {
                let author = data["sender"] as! String

                if author != self.senderId {
                    let text = data["text"] as! String
                    self.addMessage(senderId: author, name: author, text: text)
                    self.finishReceivingMessage(animated: true)
                }
            }
        })
        pusher.connect()
    }
}
