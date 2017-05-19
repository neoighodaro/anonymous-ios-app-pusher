# Add delivery status to an iOS chat app using Pusher

In our [previous article](#) we expanded our [public anonymous iOS chat application](#) by adding a someone is typing a message feature to the applicetion. In that article, we had to make some changes to the existing code base to add the feature.



### What we will be building

In this article, we will be taking it a step further by adding another feature: **delivery status** for an outgoing message. We would be adding an indication on the application that will tell us when the message is sending and when it has been delivered.

![](https://dl.dropbox.com/s/qrml2une712my9f/message-delivery-status-on-ios-using-pusher-2.gif)

### Getting Started

To get started we would be using the base application that we had created in the previous article. You can get the source to the application [on Github](https://github.com/neoighodaro/anonymous-ios-app-pusher/tree/v1.1.1). After downloading the application, unzip it and open the `.xcworkspace` file in the root of the directory, this should launch XCode. Unlike the last time, we wont be making any UI changes, just pure code additions, changes and adjustments. 

Before we continue, make sure you already have your [Pusher](https://pusher.com) application ready and replace the `PUSHER_SECRET`, `PUSHER_ID`, `PUSHER_KEY`, and `PUSHER_CLUSTER` with the one provided for your application by Pusher.

### Plan of Action

So what do we need to do to get the message delivery to be displayed in this chat application? Creating a list of things we want to do will make it that much easier to know what to do and plan better on how to do it.

* Extend the `JSQMessage` class to support new properties like `id` and `status`. With this we can track the status and the id of the message that has been sent.
* For every message check if the message is an outgoing message, if it is, check the message `status` and then set.
* When a new message is sent, check the response if it is successful, if yes, change the `status` of the message.
* Update the layout to reflect all the changes made to the message instance.



### Development

##### Extending the JSQMessage class 

The `JSQMessage` class is the class that holds the message details and it is part of the `JSQMessagesViewController` package that we pulled using cocoapods in the first article. We will extend this class by creating another class `AnonMessage` that extends it. Then we will change all the instances of `JSQMessage` class in our codebase:

```swift
import UIKit
import JSQMessagesViewController

enum AnonMessageStatus {
    case sending
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
```

In the code above we create a class and an enum where we define all the states we expect a message to exist in, you can always expand them to suite your needs.

In the class extension, we added a new way to initialise the class. This will take the new parameters `id` and `status` and assign them to the class then initialise the class using the parent method.

##### Changes to the ChatViewController

In the `didPressSend` method we will change a few things:

```Swift
override func didPressSend(_ button: UIButton, withMessageText text: String, senderId: String, senderDisplayName: String, date: Date) {
    let message = addMessage(senderId: senderId, name: senderId, text: text) as! AnonMessage

    postMessage(message: message)
    
    finishSendingMessage(animated: true)
}
```

First, the `addMessage` method will now return an `AnonMessage` instance. We will now pass this as the parameter to the `postMessage` class which makes a lot of sense.

```swift
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

private func postMessage(message: AnonMessage) {
    let params: Parameters = ["sender": message.senderId, "text": message.text]
    hitEndpoint(url: ChatViewController.API_ENDPOINT + "/messages", parameters: params, message: message)
}
```

We update the `addMessage` and `postMessage` methods to reflect the new changes. The `addMessage` function now uses the `AnonMessage` class extension as opposed to using the `JSQMessage` class. So we can now send the `status` and `id` as parameters while instantiating the `AnonMessage` class.

We will also change the contents of the `hitEndpoint` method to reflect new changes for our feature to work:

```Swift
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
```

The `hitEndpoint`  method now has a third optional `AnonMessage` paramenter we can then use this to change the status of the message when there is a successful response to `.delivered` then we can reload the data so that the changes would be apparent.

We will now make the final change to the application in our`listenForNewMessages` method:

```Swift
private func listenForNewMessages() {
    let options = PusherClientOptions(
        host: .cluster("PUSHER_CLUSTER")
    )
    
    pusher = Pusher(key: "PUSHER_KEY", options: options)
    
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
```

We have added a delivered status to the message once it is received by the Pusher listener on the application.

We will now add some few new methods that would help us display the actual message on the chat interface.

```Swift
override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAt indexPath: IndexPath!) -> NSAttributedString! {
    if !isAnOutgoingMessage(indexPath) {
        return nil
    }
    
    let message = messages[indexPath.row]

    switch (message.status) {
    case .sending:
        return NSAttributedString(string: "Sending...")
    case .delivered:
        return NSAttributedString(string: "Delivered")
    }
}

private func isAnOutgoingMessage(_ indexPath: IndexPath!) -> Bool {
    return messages[indexPath.row].senderId == senderId
}

override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAt indexPath: IndexPath!) -> CGFloat {
    return CGFloat(15.0)
}
```

In the above code, we override the a collection view that shows an attributed text at the bottom label of a chat message. This is where we will display the message status for outgoing images.

In that method, we check to see if the message `isAnOutgoingMessage` then if it is, we can then use a `switch` statement to show one or the other based on the status of the message.

In the second overriden collection view method, we specify the height of the bottom label so it is not invisible as the default is `0`. 

Thats all, we can now run our application in XCode on our iPhone simulator. You should also run the node application that is accompanied in the code.

```Shell
$ node index.js
```

Now when a message is sent on our simulator, we can see it change from  *Sending…* just after it is sent to *delivered* when the message is delivered. 

### Conclusion

Now with the changes we have made, we have been able to add delivery status to our iOS chat application using Pusher and Swift. The source code to the application is available on [GitHub](#).

![Message delivery status on iOS using Pusher](https://dl.dropbox.com/s/45snbjc0oedc7w5/message-delivery-status-on-ios-using-pusher-1.png)

This should be seen as a guide to how easy it could be to implement this feature in our application. It should probably not be used in production. As an exercise, see if you can expand the feature of the chat application by adding more message statuses like *failed* and *read*.

Have any questions or feedback, on the article? You can add them to the comment section below.