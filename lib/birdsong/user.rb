# frozen_string_literal: true

module Birdsong
  class User
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      response = self.retrieve_data(ids)
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      json_response = JSON.parse(response.body)
      json_response["data"].map do |json_user|
        User.new(json_user)
      end
    end

    # Attributes for after the response is parsed from Twitter
    attr_reader :json
    attr_reader :id
    attr_reader :name
    attr_reader :username
    attr_reader :created_at
    attr_reader :location
    attr_reader :profile_image_url

  private

    def initialize(json_user)
      @json = json_user
      parse(json_user)
    end

    def parse(json_user)
      @id = json_user["id"]
      @name = json_user["name"]
      @username = json_user["username"]
      @created_at = DateTime.parse(json_user["created_at"])
      @location = json_user["location"]
      @profile_image_url = URI(json_user["profile_image_url"])
    end

    def self.retrieve_data(ids)
      bearer_token = ENV["TWITTER_BEARER_TOKEN"]

      user_lookup_url = "https://api.twitter.com/2/users"

      # Specify the User IDs that you want to lookup below (to 100 per request)
      user_ids = ids.join(",")

      # Add or remove optional parameters values from the params object below. Full list of parameters and their values can be found in the docs:
      # https://developer.twitter.com/en/docs/twitter-api/tweets/lookup/api-reference
      params = {
        "ids": user_ids,
        "expansions": "pinned_tweet_id",
        "tweet.fields": Birdsong.tweet_fields,
        "user.fields": Birdsong.user_fields,
        # "media.fields": "url",
        # "place.fields": "country_code",
        # "poll.fields": "options"
      }

      response = self.user_lookup(user_lookup_url, bearer_token, params)
      # puts response.code, JSON.pretty_generate(JSON.parse(response.body))
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      response
    end

    def self.user_lookup(url, bearer_token, params)
      options = {
        method: "get",
        headers: {
          "User-Agent": "v2UserLookupRuby",
          "Authorization": "Bearer #{bearer_token}"
        },
        params: params
      }

      request = Typhoeus::Request.new(url, options)
      response = request.run
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      response
    end
  end
end
