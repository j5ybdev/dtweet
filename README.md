# dtweet - A small library to send tweets using curl or vibe.d's HTTP Client

Examples
--------
Example projects showing usage available under `examples/`

To run the examples you need to export your credentials:

```bash
export CONSUMER_KEY=XXX
export CONSUMER_SECRET=XXX
export TOKEN=XXX
export TOKEN_SECRET=XXX
```

Usage
-----
```d
TwitterCreds creds = {
   consumerKey: environment.get("CONSUMER_KEY"),
   consumerSecret: environment.get("CONSUMER_SECRET"),
   token: environment.get("TOKEN"),
   tokenSecret: environment.get("TOKEN_SECRET")
};

Tweeter tweeter = new VibeTweeter();
TweetResp resp = tweeter.tweet(creds,"Hello from D!");
```

Build
-----
```bash
dub build
```

Dependencies
-----
* Vibe.d
* OpenSSL 1.1.x