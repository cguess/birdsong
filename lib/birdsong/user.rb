# frozen_string_literal: true

module Birdsong
  class User
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }
      self.lookup_primative(ids: ids)
    end

    def self.lookup_by_usernames(usernames = [])
      # If a single id is passed in we make it the appropriate array
      usernames = [usernames] unless usernames.kind_of?(Array)
      self.lookup_primative(usernames: usernames)
    end

    # Attributes for after the response is parsed from Twitter
    attr_reader :json
    attr_reader :id
    attr_reader :name
    attr_reader :username
    attr_reader :sign_up_date
    attr_reader :location
    attr_reader :profile_image_url
    attr_reader :description
    attr_reader :url
    attr_reader :followers_count
    attr_reader :following_count
    attr_reader :tweet_count
    attr_reader :listed_count
    attr_reader :verified
    attr_reader :created_at
    attr_reader :profile_image_file_name

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

      # Removing the "normal" here gets us the full-sized image, instead of the 150x150 thumbnail
      @profile_image_url = json_user["profile_image_url"].sub!("_normal", "")

      @description = json_user["description"]
      @url = json_user["url"]
      @url = "https://www.twitter.com/#{@username}" if @url.nil?
      @followers_count = json_user["public_metrics"]["followers_count"]
      @following_count = json_user["public_metrics"]["following_count"]
      @tweet_count = json_user["public_metrics"]["tweet_count"]
      @listed_count = json_user["public_metrics"]["listed_count"]
      @verified = json_user["verified"]
      @profile_image_file_name = Birdsong.retrieve_media(@profile_image_url)
    end

    def self.lookup_primative(usernames: nil, ids: nil)
      raise Birdsong::InvalidIdError if usernames.nil? && ids.nil? # can't pass in nothing
      raise Birdsong::InvalidIdError if usernames.nil? == false && ids.nil? == false # don't pass in both

      response = self.retrieve_data(ids: ids, usernames: usernames)

      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      json_response = JSON.parse(response.body)
      return [] if json_response["data"].nil?

      json_response["data"].map do |json_user|
        User.new(json_user)
      end
    end

    def self.retrieve_data(usernames: nil, ids: nil)
      bearer_token = Birdsong.twitter_bearer_token

      raise Birdsong::InvalidIdError if usernames.nil? && ids.nil? # can't pass in nothing
      raise Birdsong::InvalidIdError if usernames.nil? == false && ids.nil? == false # don't pass in both

      # Add or remove optional parameters values from the params object below. Full list of parameters and their values can be found in the docs:
      # https://developer.twitter.com/en/docs/twitter-api/tweets/lookup/api-reference
      params = {
        "expansions": "pinned_tweet_id",
        "tweet.fields": Birdsong.tweet_fields,
        "user.fields": Birdsong.user_fields,
      }

      if usernames.nil? == false
        user_lookup_url = "https://api.twitter.com/2/users/by"
        # Specify the Usernames that you want to lookup below (to 100 per request)
        params["usernames"] = usernames.join(",")
      elsif ids.nil? == false
        user_lookup_url = "https://api.twitter.com/2/users"
        # Specify the User IDs that you want to lookup below (to 100 per request)
        params["ids"] = ids.join(",")
      end

      response = self.user_lookup(user_lookup_url, bearer_token, params)

      raise Birdsong::RateLimitExceeded.new(
        response.headers["x-rate-limit-limit"],
        response.headers["x-rate-limit-remaining"],
        response.headers["x-rate-limit-reset"]
      ) if response.code === 429
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

      raise Birdsong::RateLimitExceeded.new(
        response.headers["x-rate-limit-limit"],
        response.headers["x-rate-limit-remaining"],
        response.headers["x-rate-limit-reset"]
      ) if response.code === 429
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      response
    end
  end
end
