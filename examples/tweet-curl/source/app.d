import std.process : environment;
import std.exception : enforce;
import std.stdio : writefln;
import dtweet;

void main(string[] arg) {

   string msg = "Hello from D!";
   if (arg.length > 1) {
      msg = arg[1];
   }

   try {
      TwitterCreds creds = {
         consumerKey: environment.get("CONSUMER_KEY")
            .enforce("CONSUMER_KEY environment variable is not defined."),
         consumerSecret: environment.get("CONSUMER_SECRET")
            .enforce("CONSUMER_SECRET environment variable is not defined."),
         token: environment.get("TOKEN")
            .enforce("TOKEN environment variable is not defined."),
         tokenSecret: environment.get("TOKEN_SECRET")
            .enforce("TOKEN_SECRET environment variable is not defined.")
      };

      Tweeter tweeter = new CurlTweeter();
      TweetResp resp = tweeter.tweet(creds, msg);

      writefln("Tweet success: %s\n%s", resp.isSuccess(), resp.respBody);

   } catch (Exception e) {
      writefln("%s", e.msg);
   }
}
