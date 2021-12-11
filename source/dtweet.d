module dtweet;

import std.range;
import std.conv : to;
import std.typecons : tuple, Tuple;
import std.digest.hmac : HMAC;
import std.digest.sha : SHA1;
import std.digest : toHexString;
import std.string : representation;
import std.base64;
import std.format : format;
import std.uuid;
import std.datetime : Clock;

interface Tweeter {
   TweetResp tweet(in ref TwitterCreds creds, string msg);
}

class VibeTweeter : Tweeter {

   /**
   * Send out one tweet message to the twitter API
   */
   TweetResp tweet(in ref TwitterCreds creds, string msg) {
      import vibe.vibe : HTTPMethod, readAllUTF8;
      import vibe.http.client : requestHTTP;

      const string authHdr = getAuthHeader(creds,msg);
      TweetResp resp;

      requestHTTP(TWEET_URL,
         (scope req) {
            req.method = HTTPMethod.POST;
            req.headers[HDR_AUTHORIZATION] = authHdr;
            req.writeFormBody([PARAM_STATUS: msg]);
         },
         (scope res) {
            resp.statusCode = to!short(res.statusCode);
            resp.contentType = res.headers[HDR_CONTENT_TYPE];
            resp.respBody = res.bodyReader.readAllUTF8();
            res.destroy();
         }
      );

      return resp;
   }
}

class CurlTweeter : Tweeter {

   /**
   * Send out one tweet message to the twitter API
   */
   TweetResp tweet(in ref TwitterCreds creds, string msg) {
      import std.net.curl : HTTP;

      const string authHdr = getAuthHeader(creds,msg);
      const string payload = format("%s=%s", PARAM_STATUS, urlEncode(msg));

      TweetResp resp;
      auto http = HTTP(TWEET_URL);
      http.method(HTTP.Method.post);
      http.addRequestHeader(HDR_AUTHORIZATION, authHdr);
      http.setPostData(payload, CONTENT_TYPE_FORM);
      http.onReceiveHeader = (in char[] key, in char[] value) {
         if (key == HDR_CONTENT_TYPE) {
            resp.contentType = value.dup;
         }
      };
      http.onReceive = (ubyte[] data) {
         resp.respBody = cast(string) data;
         return data.length;
      };
      http.onReceiveStatusLine = (HTTP.StatusLine status) {
         resp.statusCode = status.code;
      };
      http.perform();

      return resp;
   }
}

class NoOpTweeter : Tweeter {

   TweetResp tweet(in ref TwitterCreds creds, string msg) {
      TweetResp resp = {
         statusCode: 200,
         contentType: CONTENT_TYPE_TEXT,
         respBody: ""
      };
      return resp;
   }
}

struct TweetResp {
   short statusCode;
   string contentType;
   string respBody;

   bool isSuccess() {
      return statusCode >= 200 && statusCode < 300;
   }
}

struct TwitterCreds {
   /// API Key
   string consumerKey;
   /// API Secret Key
   string consumerSecret;
   /// access token
   string token; 
   /// value which identifies the account your application is acting on behalf of
   string tokenSecret;
}

enum TWEET_URL = TWITTER_API_TWEET ~ "?" ~ PARAM_INC_ENTITIES ~ "=" ~ INC_ENTITIES;

/**
* Calculate and return the Authorization header required to authorize the tweet
*/
string getAuthHeader(in ref TwitterCreds creds, string msg) {
   long now = cast(long) Clock.currTime().toUnixTime();
   const string nounce = newNounce();
   const string sig    = signRequest(creds,nounce,now,msg);
   return buildAuthHeader(creds,nounce,sig,now);
}


private enum TWITTER_API_TWEET = "https://api.twitter.com/1.1/statuses/update.json";
private enum AUTH_TYPE = "OAuth";
private enum OAUTH_VERSION = "1.0";
private enum OAUTH_SIG_METHOD = "HMAC-SHA1";
private enum PARAM_INC_ENTITIES = "include_entities";
private enum PARAM_STATUS = "status";
private enum PARAM_CONSUMER_KEY = "oauth_consumer_key";
private enum PARAM_NOUNCE = "oauth_nonce";
private enum PARAM_SIG = "oauth_signature";
private enum PARAM_SIG_METHOD = "oauth_signature_method";
private enum PARAM_TIMESTAMP = "oauth_timestamp";
private enum PARAM_TOKEN = "oauth_token";
private enum PARAM_VERSION = "oauth_version";
private enum INC_ENTITIES = "true";
private enum CONTENT_TYPE_FORM = "application/x-www-form-urlencoded";
private enum CONTENT_TYPE_TEXT = "text/plain";
private enum HDR_AUTHORIZATION = "Authorization";
private enum HDR_CONTENT_TYPE = "Content-Type";

private string signRequest(in ref TwitterCreds creds, string nounce, long timestamp, string msg) {
   Tuple!(string, string)[] params;
   params.reserve(8);
   params ~= tuple(PARAM_INC_ENTITIES,INC_ENTITIES);
   params ~= tuple(PARAM_CONSUMER_KEY,creds.consumerKey);
   params ~= tuple(PARAM_NOUNCE,nounce);
   params ~= tuple(PARAM_SIG_METHOD,OAUTH_SIG_METHOD);
   params ~= tuple(PARAM_TIMESTAMP,to!string(timestamp));
   params ~= tuple(PARAM_TOKEN,creds.token);
   params ~= tuple(PARAM_VERSION,OAUTH_VERSION);
   params ~= tuple(PARAM_STATUS,urlEncode(msg));
   
   auto p1 = appender!string();
   string sep = "";
   foreach (ref p; params) {
      p1 ~= sep;
      p1 ~= p[0];
      p1 ~= "=";
      p1 ~= p[1];
      sep = "&";
   }

   const string signingKey = urlEncode(creds.consumerSecret) ~ "&" ~ urlEncode(creds.tokenSecret);
   auto sigBase = appender!string();
   sigBase ~= "POST&";
   sigBase ~= urlEncode(TWITTER_API_TWEET);
   sigBase ~= "&";
   sigBase ~= urlEncode(p1.data);

   auto hmac = HMAC!SHA1(signingKey.representation);
   auto digest = hmac.put(sigBase.data.representation).finish();
   string dig64 = Base64.encode(digest);

   return dig64;
}

unittest {
   TwitterCreds creds = {
      consumerKey: "xvz1evFS4wEEPTGEFPHBog",
      consumerSecret: "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
      token: "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb",
      tokenSecret: "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE"
   };
   const long timestamp = 1318622958;
   const string nounce = "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg";
   const string msg = "Hello Ladies + Gentlemen, a signed OAuth request!";
   assert(signRequest(creds,nounce,timestamp,msg) == "hCtSmYh+iHYCEqBWrE7C7hYmtUk=");
}

/**
* Generate a random alpha numeric string
*/
private string newNounce() {

   auto preNounce = appender!string();
   enum c1 = '-';
   enum c2 = '=';

   Base64Impl!(c1, c2, Base64.NoPadding).encode(randomUUID().data, preNounce);
   Base64Impl!(c1, c2, Base64.NoPadding).encode(randomUUID().data, preNounce);

   return preNounce.data.replace(c1,"").replace(c2,"");
}

unittest {
   // nounce should be all aplha numeric
   import std.ascii : isAlphaNum;
   const string nounce = newNounce();
   bool alphaNum = true;
   foreach(n; nounce) {
      alphaNum &= isAlphaNum(n);
   }
   assert(alphaNum);
   assert(nounce.length > 20);
}

/**
* Produces the 'Authorization' HTTP header the authorizes the API request
*/
private string buildAuthHeader(in ref TwitterCreds creds, string nounce, string sig, long timestamp) {

   Tuple!(string, string)[] params;
   params.reserve(8);

   params ~= tuple(PARAM_CONSUMER_KEY,creds.consumerKey);
   params ~= tuple(PARAM_NOUNCE,nounce);
   params ~= tuple(PARAM_SIG,sig);
   params ~= tuple(PARAM_SIG_METHOD,OAUTH_SIG_METHOD);
   params ~= tuple(PARAM_TIMESTAMP,to!string(timestamp));
   params ~= tuple(PARAM_TOKEN,creds.token);
   params ~= tuple(PARAM_VERSION,OAUTH_VERSION);
   
   auto hdr = appender!string();
   hdr ~= AUTH_TYPE;
   string sep = "";
   foreach (ref p; params) {
      hdr ~= sep;
      hdr ~= " ";
      hdr ~= urlEncode(p[0]);
      hdr ~= "=\"";
      hdr ~= urlEncode(p[1]);
      hdr ~= "\"";
      sep = ",";
   }

   return hdr.data;
}

/**
* Encode URL parameters.
* Must abide by RFC 3986, Section 2.1 to avoid Oauth signature failures.
* See https://developer.twitter.com/en/docs/authentication/oauth-1-0a/percent-encoding-parameters
*/
private string urlEncode(string inStr) {
   import vibe.vibe : urlEncode;
   return urlEncode(inStr);
}

unittest {
   TwitterCreds creds = {
      consumerKey: "xvz1evFS4wEEPTGEFPHBog",
      consumerSecret: "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
      token: "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb",
      tokenSecret: "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE"
   };
   const long timestamp = 1318622958;
   const string sig = "tnnArxj06cWHq44gCs1OSKk/jLY=";
   const string nounce = "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg";
   assert(buildAuthHeader(creds,nounce,sig,timestamp) == "OAuth"
      ~ " oauth_consumer_key=\"xvz1evFS4wEEPTGEFPHBog\","
      ~ " oauth_nonce=\"kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg\","
      ~ " oauth_signature=\"tnnArxj06cWHq44gCs1OSKk%2FjLY%3D\","
      ~ " oauth_signature_method=\"HMAC-SHA1\","
      ~ " oauth_timestamp=\"1318622958\","
      ~ " oauth_token=\"370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb\","
      ~ " oauth_version=\"1.0\"");
}
