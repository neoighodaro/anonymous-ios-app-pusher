# Create an anonymous public iOS chat app

In this article we are going to be demonstrating how to create a public anonymous chat application on iOS. This will guide you on how easy it can actually be to create your ery own chat application and also how you can use Pusher to integrate some real-time functionality into it.

This article assumes you already have a working knowledge on Swift and XCode. You will also need to have a pusher application set up. You can get a pusher account free by clicking [here](https://pusher.com)

> When you are creating a pusher application, don't forget to select a cluster and make sure it is the same cluster used when defining the keys in your application

![create ann anonymous public ios chat app](https://dl.dropbox.com/s/6htmhtlhf4y07h2/create-an-anonymous-chat-app-ios-3.png)



## What we will be building

Our application will be a highly ephemeral application that does not save state. We will be using Pusher to send the messages and listen for new ones on the application. We will also build a web app using Node to be the server side app that handles the pusher event triggers.

![Create an anonymous iOS chat app using Pusher](https://dl.dropbox.com/s/xemmkpaqlrfc7tp/create-an-anonymous-chat-app-ios-1.gif)

### Setting your project up

The first thing you will need to do is create a new XCode project. When you have created a new project we will use Cocoapods to manage the dependencies the application might currently have. If you have not already, install cocoapods on your machinne.

```swift
$ gem install cocoapods
```

Now to use cocoapods in our application, cd to the code directory and run `pod init` this will create a `Podfile` and this is where we will be defining our dependencies for the application. Open the `Podfile` in your text editor of choice and replace with the content below:

```
# Uncomment the next line to define a global platform for your project
platform :ios, '9.0'

target 'anonchat' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for anonchat
  pod 'Alamofire'
  pod 'PusherSwift'
  pod 'JSQMessagesViewController'
end
```

After you are done, run the command `pod install` and this will download the dependencies specified in the `Podfile`. When this is complete, close XCode if open and then open the `.xcworkspace` file that is in the root of your project folder.

### Creating the views necessary

For login, we have decided to keep it simple. Since this is an anonymous chat application, we would generate the username for the user internally.

Create the login view using the storyboard interface builder. Here is what I have created using the builder. The "Login anonymously" button would be the trigger to push the next controller in.

The next controller is a navigation controller. This will be the one loaded after the login button is clicked. This in turn has a root controller which is out `ChatViewController` and this extends the `JSQMessagesViewController` which will give us the chat like interface automatically. Neat right?

Here is the storyboard after all the pieces have been assembled.

![Create an anonymous public ios chat app using Pusher](https://dl.dropbox.com/s/sbbwnm4jqqprs8b/create-an-anonymous-chat-app-ios-2.png)

### Coding the logic into the views

Now we have created the views and interface necessary to work with the application. Now we need to write some code. Create a `ChatViewController` and associate it to the chat view that we created above.

Now we need to extend the `ChatViewController` so we will enjoy the goodness our `JSQMessagesViewController` provides. We will also need to import all the dependencies we need at the top

```swift
import UIKit
import Alamofire
import PusherSwift
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
}
```

Now let us start adding functionality to the controller.

First we want to add a messages array that will contain all the messages in this current session. Then we will create a pusher instance that will listen for new messages and then append the message to the messages array.

```Swift
import UIKit
import Alamofire
import PusherSwift
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
    var messages = [JSQMessage]()
    var pusher : Pusher!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        listenForNewMessages()
    }

    private func listenForNewMessages() {
        pusher = Pusher(key: "ENTER_PUSHER_KEY_HERE")
        
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
    
    private func addMessage(senderId: String, name: String, text: String) {
        if let message = JSQMessage(senderId: senderId, displayName: name, text: text) {
            messages.append(message)
        }
    }
}
```

So above in the `viewDidLoad` method, we called `listenForNewMessages` which does as it is titled and listens for new Pusher events/messages. Then it calls the `addMessage` method which appends to the messages array.

The next thing we want to do is customise our chat interface using the `JSQMessagesViewController`  class we are currently extending.

First we will define some properties in the `ChatViewController` class

```Swift
var incomingBubble: JSQMessagesBubbleImage!
var outgoingBubble: JSQMessagesBubbleImage!
```

Next, we will customise the interface in the `viewDidLoad`:

```swift
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
}
```

We will also continue customising the interface by overriding some of the methods provided by the `JSQMessagesViewController`. Lets add these methods to our `ChatViewController`

```swift
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
```

Next we have to generate the username for the user automatically so in the `viewDidLoad` method lets add the following:

```Swift
let n = Int(arc4random_uniform(1000))

senderId = "anonymous" + String(n)
senderDisplayName = senderId
```

This will create a username anonymous plus a random number between 0 and 999. That should suffice for now.

The final piece of the puzzle now is adding the `postMessage` method which will post the message to our Node application backend. That application will send the message down to Pusher and it will be ready for pick up by any listener on that Pusher channel.

```swift
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
```

 We will also have to define this property `ChatViewController.API_ENDPOINT`.

```swift
static let API_ENDPOINT = "http://localhost:4000";
```

We will be using local host but if you already have it online that is great too.

### Building the backend Node application

Now that we are done with the iOS and XCode parts, we can now create the NodeJS back end for the application. We are going to be using express, so that we can quickly whip something up.

Create a directory for the web application and then create two new files

```javascript
// index.js
var path = require('path');
var Pusher = require('pusher');
var express = require('express');
var bodyParser = require('body-parser');

var app = express();

var pusher = new Pusher({
  appId: 'PUSHER_APP_ID',
  key: 'PUSHER_APP_KEY',
  secret: 'PUSHER_APP_SECRET',
  cluster: 'mt1',
  encrypted: true
});

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

app.post('/messages', function(req, res){
  var message = {
    text: req.body.text,
    sender: req.body.sender
  }
  pusher.trigger('chatroom', 'new_message', message);
  res.json({success: 200});
});

app.use(function(req, res, next) {
    var err = new Error('Not Found');
    err.status = 404;
    next(err);
});

module.exports = app;

app.listen(4000, function(){
  console.log('App listening on port 4000!')
})
```

and **packages.json**

```json
{
  "main": "index.js",
  "dependencies": {
    "body-parser": "^1.16.0",
    "express": "^4.14.1",
    "path": "^0.12.7",
    "pusher": "^1.5.1"
  }
}
```

Now run `npm install` on the directory and then `node index.js` once the npm installation is complete. You should see _App listening on port 4000!_ message.

### Testing the application

Once you have your local node webserver running, you will need to make you will need to make some changes so your application can talk to the local webserver.

In the `info.plist` file, make the following changes:

![Create an anonymous iOS chat app using pusher](https://dl.dropbox.com/s/evqxjkgvukcsgk4/create-an-anonymous-chat-app-ios-4.png)
Now with this change, your application can now talk directly with your local web application.

### Conclusion

We have managed to create an application that works as a public chat application on iOS using Swift and Pusher. In another article, we would expand this application to have a who is typing feature and a delivery status.

Have a question or feedback on the article? Please ask below in the comment section. The repository for the application and the Node backend is available [here](https://github.com/neoighodaro/anonymous-ios-app-pusher).