# How to build a who's typing feature in iOS

In our previous article we considered [How to create a public anonymous iOS chat application](#). We were able to create the application using Swift and Pusher so the application wont save state.

In this article, we are going to expand that application and add a who's typing feature to the application. If you have not read the previous article, I suggest you do so, but if you do not want to then you can grab the [source code to the article here](https://github.com/neoighodaro/anonymous-ios-app-pusher) and follow along.

## What we will be building

As mentioned earlier, we will be adding a who's typing feature to our application. This is supposed to indicate that someone is typing a message on the other end just like WhatsApp, WeChat or instant messaging clients do.

![How to build a who's typing feature in iOS](https://dl.dropbox.com/s/j8a4hqcddx7kvpb/add-whos-typing-feature-ios-app-using-pusher-1.gif)

### Setting up the application

Open the root directory of the source code you downloaded above, then, open the `.xcworkspace` file included in the directory; this should launch XCode. Now we already have a storyboard. In the story board we have an entry controller, and this has a button to login anonymously. Clicking the button leads to the navigation controller which in turn loads the `ChatViewController`.

![How to build a who's typing feature in iOS](https://dl.dropbox.com/s/9vt5qhmy9pj1p63/add-whos-typing-feature-ios-app-using-pusher-2.png)

> **Note**: To test the application you might need to customise the Pusher application credentials in the `ChatViewController` and the `index.js` file in the web app directory. You will also need to run `node index.js` in the webapp directory to start a local webserver.

### What we need to do

To make this application do what we need it to do we need to do some new things. First, we will add a text field in the login screen that allows the user input whatever username they want to be known as. Next, we will add a new endpoint to the web server application that will trigger Pusher once someone starts typing. We will add a new listener in the application that listens in for when someone is typing and finally we will trigger the new endpoint when someone is entering text into the 'New message' field.

Drag a textfield to the login view and make it look like what is in the screenshot below. 

![How to build a who's typing feature in iOS](https://dl.dropbox.com/s/vi72z93rudgih94/add-whos-typing-feature-ios-app-using-pusher-3.png)

#### Updating the Login Controller

Open the split view and make sure the `WelcomeViewController` is the one on the right. You have to now create an `@IBOutlet` for both the login textfield and an `@IBAction` for the login button. Your `WelcomeViewController` should now look something like this:

```swift
import UIKit

class WelcomeViewController: UIViewController {
    var username : String = ""

    @IBOutlet weak var loginBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func editingUsername(_ sender: UITextField) {
    }
}
```

Now we need to add some validation to the text field and then when the validation passes, we can then assign the username entered to the `ChatViewController` and load the `ChatViewController`.

```swift
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
```

This is the full `WelcomeViewController` after we have effected the changes. As you can see, the `editingUsername` checks to see if there is actually text, then if the username is 3 characters and longer. It then checks to see if there are `noCaps` and finally if there are `noSpaces`/. If all these pass then it sets the username. The `prepare` method then uses the `setSenderId` on the `ChatViewController` to set the username to a property in there.

#### Adding the endpoint on the web server

Now we want to add an endpoint on the web server that will trigger Pusher events everytime someone is typing. Open the `index.js`  in the `webapp` directory on your editor of choice. You can now add the `/typing` endpoint to the code as shown below:

```javascript
app.post('/typing', function (req, res) {
  var message = {
    sender: req.body.sender,
    text: req.body.sender + " is typing..."
  };
  pusher.trigger('chatroom', 'user_typing', message);
  res.json({success: 200})
})
```

So now, everytime we hit the `/typing` endpoint, it should trigger pusher with the message `senderId is typing…`. Great.

#### Triggering Pusher from the application when typing

The next thing to do would be to trigger Pusher everytime the current user is typing on the application. This would basically hit the `/typing` endpoint we just created with the `username` as the `sender` parameter.

To make sure we keep our code DRY, we have refactored the code a little. We have abstracted the part that hits our endpoint into one method called `hitEndpoint` and we use that now whenever we want to hit the endpoint.

```Swift
var isBusySendingEvent : Bool = false

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

override func textViewDidChange(_ textView: UITextView) {
    super.textViewDidChange(textView)
    sendIsTypingEvent(forUser: senderId)
}
```

In the `sendIsTypingEvent` we have a quick flag that we use to stop the application from sending too many requests especially if the last one has not been fulfilled. Because we trigger this method everytime someone changes something on the text field this check is necessary.

#### Adding a listener to pick when others are typing

The last piece of the puzzle is adding a listener that picks up when someone else is typing and changes the view controllers title bar to `someone is typing…`. To do this, we would use the `subscribe` method on the `PusherChannel` object. 

```Swift
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

private func listenForNewMessages() {
    let options = PusherClientOptions(
        host: .cluster("PUSHER_CLUSTER")
    )
    
    pusher = Pusher(key: "PUSHER_ID", options: options)
    
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

public func isTypingEventExpireAction() {
    navigationItem.title = "AnonChat"
}
```

Above we made some changes, in the `listenForNewMessages` we added a new subscriotion to the `user_typing` event, and in the `viewDidLoad` method, we added a timer that just runs on intervals and resets the title of the application. So basically, the subscriber picks up the changes in the event from pusher, updates the navigation title, then the timer resets the title every x seconds.

With this we have completed our task and we should have a functioning who is typing feature.

### Conclusion

There are many improvements you can obviously add to make the experience a little more seemless, but this demonstrates how the feature can be implemented easily into your iOS application. Have an idea you want to incorporate or just some feedback? Please leave a comment below and tell us what it is.

In the next article, we are going to see how to add a message delivered feature to our chat application. As practise, see if you can implement this yourself.