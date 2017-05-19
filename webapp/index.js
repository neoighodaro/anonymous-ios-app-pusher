var path = require('path');
var Pusher = require('pusher');
var express = require('express');
var bodyParser = require('body-parser');
var sleep = require('sleep');

var app = express();

var pusher = new Pusher({
  appId: 'PUSHER_ID',
  key: 'PUSHER_KEY',
  secret: 'PUSHER_SECRET',
  cluster: 'PUSHER_CLUSTER',
  encrypted: true
});

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

app.post('/messages', function(req, res){
  var message = {
    text: req.body.text,
    sender: req.body.sender
  }

  // @DEV: Simulate network delays...
  sleep.sleep(2);

  pusher.trigger('chatroom', 'new_message', message);
  res.json({success: 200});
});

app.post('/typing', function (req, res) {
  var message = {
    sender: req.body.sender,
    text: req.body.sender + " is typing..."
  };
  pusher.trigger('chatroom', 'user_typing', message);
  res.json({success: 200})
})

app.use(function(req, res, next) {
    var err = new Error('Not Found');
    err.status = 404;
    next(err);
});

module.exports = app;

app.listen(4000, function(){
  console.log('App listening on port 4000!')
})