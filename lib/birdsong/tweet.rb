# frozen_string_literal: true

require "byebug"

module Birdsong
  class Tweet
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      response = self.retrieve_data_v2(ids)
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code == 200

      json_response = JSON.parse(response.body)
      check_for_errors(json_response)

      return [] if json_response["data"].nil?

      json_response["data"].map do |json_tweet|
        Tweet.new(json_tweet, json_response["includes"])
      end
    end

    # Attributes for after the response is parsed from Twitter
    attr_reader :json
    attr_reader :id
    attr_reader :created_at
    attr_reader :text
    attr_reader :language
    attr_reader :author_id
    attr_reader :author
    attr_reader :image_file_names
    attr_reader :video_file_names

  private

    def initialize(json_tweet, includes)
      @json = json_tweet
      parse(json_tweet, includes)
    end

    def parse(json_tweet, includes)
      @id = json_tweet["id"]
      @created_at = DateTime.parse(json_tweet["created_at"])
      @text = json_tweet["text"]
      @language = json_tweet["lang"]
      @author_id = json_tweet["author_id"]

      unless includes["media"].nil?
        # A sanity check to make sure we have everything in there correctly
        media_items = includes["media"].filter do |media_item|
          json_tweet["attachments"]["media_keys"].include? media_item["media_key"]
        end

        @image_file_names = media_items.map do |media_item|
          next unless media_item["type"] == "photo"
          Birdsong.retrieve_media(media_item["url"])
        end.compact # compact because of the `next` above will return `nil`

        @video_file_names = media_items.map do |media_item|
          next unless media_item["type"] == "video"

          # If the media is video we need to fall back to V1 of the API since V2 doesn't support
          # videos yet. This is dumb, but not a big deal.
          response = Tweet.retrieve_data_v1(@id)
          response = JSON.parse(response.body)

          # The API response is pretty deeply nested, but this handles that structure
          largest_bitrate_variant = nil
          response["extended_entities"]["media"].each do |entity|
            # The API returns multiple different resolutions usually. Since we only want to archive
            # the largest we'll run through and find it
            entity["video_info"]["variants"].each do |variant|
              # There may be a .m3u playlist (for streaming I'm guessing), but we don't want that.
              next unless variant["content_type"] == "video/mp4"

              if largest_bitrate_variant.nil? || (largest_bitrate_variant["bitrate"] < variant["bitrate"])
                largest_bitrate_variant = variant
              end
            end
          end

          Birdsong.retrieve_media(largest_bitrate_variant["url"])
        end.compact # compact because of the `next` above will return `nil`
      else
        @image_file_names = []
        @video_file_names = []
      end

      # Look up the author given the new id.
      # NOTE: This doesn't *seem* like the right place for this, but I"m not sure where else
      @author = User.lookup(@author_id).first
    end

    def self.retrieve_data_v2(ids)
      bearer_token = ENV["TWITTER_BEARER_TOKEN"]

      tweet_lookup_url = "https://api.twitter.com/2/tweets"

      # Specify the Tweet IDs that you want to lookup below (to 100 per request)
      tweet_ids = ids.join(",")

      # Add or remove optional parameters values from the params object below. Full list of parameters and their values can be found in the docs:
      # https://developer.twitter.com/en/docs/twitter-api/tweets/lookup/api-reference
      params = {
        "ids": tweet_ids,
        "expansions": "attachments.media_keys,author_id,referenced_tweets.id",
        "tweet.fields": Birdsong.tweet_fields,
        "user.fields": Birdsong.user_fields,
        "media.fields": "duration_ms,height,media_key,preview_image_url,public_metrics,type,url,width",
        "place.fields": "country_code",
        "poll.fields": "options"
      }

      response = tweet_lookup_v2(tweet_lookup_url, bearer_token, params)
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code === 200

      response
    end

    def self.tweet_lookup_v2(url, bearer_token, params)
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

    # Note that unlike the V2 this only supports one url at a time
    def self.retrieve_data_v1(id)
      bearer_token = ENV["TWITTER_BEARER_TOKEN"]

      tweet_lookup_url = "https://api.twitter.com/1.1/statuses/show.json?tweet_mode=extended&id=#{id}"

      response = tweet_lookup_v1(tweet_lookup_url, bearer_token)
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code === 200

      response
    end

    # V2 of the Twitter API (which we use everywhere else) doesn't include videos or gifs yet,
    # so we have to fall back to V1.
    #
    # There's a tracker for this at https://twittercommunity.com/t/where-would-i-find-the-direct-link-to-an-mp4-video-posted-in-v2/146933/2
    def self.tweet_lookup_v1(url, bearer_token)
      options = {
        method: "get",
        headers: {
          "Authorization": "Bearer #{bearer_token}"
        }
      }

      request = Typhoeus::Request.new(url, options)
      response = request.run

      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code === 200

      response
    end


    def self.check_for_errors(parsed_json)
      return false unless parsed_json.keys.include?("errors")
      return false if parsed_json["errors"].empty?
      parsed_json["errors"].each do |error|
        if error["title"] == "Not Found Error"
          raise Birdsong::NoTweetFoundError, "Tweet with id #{error["value"]} not found"
        end
      end
      false
    end
  end
end
