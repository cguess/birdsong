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
      @id = json_user["id"].to_s
      @name = json_user["name"]
      @username = json_user["screen_name"]
      @created_at = DateTime.parse(json_user["created_at"])
      @location = json_user["location"]

      # Removing the "normal" here gets us the full-sized image, instead of the 150x150 thumbnail
      @profile_image_url = json_user["profile_image_url"].sub!("_normal", "")

      @description = json_user["description"]
      @url = json_user["url"]
      @url = "https://www.twitter.com/#{@username}" if @url.nil?

      @followers_count = json_user["followers_count"]
      @following_count = json_user["friends_count"]
      @tweet_count = json_user["statuses_count"]
      @listed_count = json_user["listed_count"]
      @verified = json_user["verified"] # this will always be `false` but we're keeping it here for compatibility
      @profile_image_file_name = Birdsong.retrieve_media(@profile_image_url)
    end

    def self.lookup_primative(usernames: [], ids: [])
      raise Birdsong::InvalidIdError if usernames.empty? && ids.empty? # can't pass in nothing

      if usernames.empty? == false
        response = usernames.map { |username| self.retrieve_data(username: username) }
      elsif ids.empty? == false
        response = ids.map { |id| self.retrieve_data(id: id) }
      else
        raise Birdsong::InvalidIdError
      end

      json_response = response.map { |r| JSON.parse(r.body) }

      json_response.map do |json_user|
        User.new(json_user)
      end
    end

    def self.retrieve_data(username: nil, id: nil)
      bearer_token = Birdsong.twitter_bearer_token

      raise Birdsong::InvalidIdError if username.nil? && id.nil? # can't pass in nothing
      raise Birdsong::InvalidIdError if username.nil? == false && id.nil? == false # don't pass in both

      user_lookup_url = "https://api.twitter.com/1.1/users/show.json"

      params = {}
      if username.nil? == false
        # Specify the Usernames that you want to lookup below (to 100 per request)
        params["screen_name"] = username
      elsif id.nil? == false
        # Specify the User IDs that you want to lookup below (to 100 per request)
        params["user_id"] = id
      end

      response = self.user_lookup(user_lookup_url, bearer_token, params)

      raise Birdsong::RateLimitExceeded.new(
        response.headers["x-rate-limit-limit"],
        response.headers["x-rate-limit-remaining"],
        response.headers["x-rate-limit-reset"]
      ) if response.code === 429
      raise Birdsong::NoTweetFoundError, "User with id #{id} or username #{username} not found" if response.code === 404
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
