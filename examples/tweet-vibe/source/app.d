import std.process : environment;
import dtweet;
import vibe.vibe;

void main(string[] arg) {

   string msg = "Hello from D!";
   readOption("msg", &msg, "The message to tweet");

   runTask(() nothrow {
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

         Tweeter tweeter = new VibeTweeter();
         TweetResp resp = tweeter.tweet(creds, msg);

         logInfo("Tweet success: %s\n%s", resp.isSuccess(), resp.respBody);


      } catch (Exception e) {
         logError("%s", e.msg);
      }
		exitEventLoop();
	});

	runApplication();
}
