# frozen_string_literal: true

require "byebug"

module Birdsong
  class Tweet
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      response = self.retrieve_data(ids)
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      json_response = JSON.parse(response.body)
      return [] if json_response["data"].nil?

      json_response["data"].map do |json_tweet|
        Tweet.new(json_tweet)
      end
    end

    # Attributes for after the response is parsed from Twitter
    attr_reader :json
    attr_reader :id
    attr_reader :created_at
    attr_reader :text
    attr_reader :language

  private

    def initialize(json_tweet)
      @json = json_tweet
      parse(json_tweet)
    end

    def parse(json_tweet)
      @id = json_tweet["id"]
      @created_at = DateTime.parse(json_tweet["created_at"])
      @text = json_tweet["text"]
      @language = json_tweet["lang"]
    end

    def self.retrieve_data(ids)
      bearer_token = ENV["TWITTER_BEARER_TOKEN"]

      tweet_lookup_url = "https://api.twitter.com/2/tweets"

      # Specify the Tweet IDs that you want to lookup below (to 100 per request)
      tweet_ids = ids.join(",")

      # Add or remove optional parameters values from the params object below. Full list of parameters and their values can be found in the docs:
      # https://developer.twitter.com/en/docs/twitter-api/tweets/lookup/api-reference
      params = {
        "ids": tweet_ids,
        "expansions": "author_id,referenced_tweets.id",
        "tweet.fields": Birdsong.tweet_fields,
        "user.fields": Birdsong.user_fields,
        "media.fields": "url",
        "place.fields": "country_code",
        "poll.fields": "options"
      }

      response = tweet_lookup(tweet_lookup_url, bearer_token, params)
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code === 200
      # puts response.code, JSON.pretty_generate(JSON.parse(response.body))
      response
    end

    def self.tweet_lookup(url, bearer_token, params)
      options = {
        method: "get",
        headers: {
          "User-Agent": "v2TweetLookupRuby",
          "Authorization": "Bearer #{bearer_token}"
        },
        params: params
      }

      request = Typhoeus::Request.new(url, options)
      response = request.run

      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code === 200

      response
    end
  end
end
