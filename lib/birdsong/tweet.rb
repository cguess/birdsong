# frozen_string_literal: true

module Birdsong
  class Tweet
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      response = ids.map { |id| self.retrieve_data_v1(id) }

      json_response = response.map { |r| JSON.parse(r.body) }
      check_for_errors(json_response)

      json_response.map do |json_tweet|
        Tweet.new(json_tweet)
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
    attr_reader :video_file_type

    alias_method :user, :author # Every other gem uses `user` so we can just alias it

  private

    def initialize(json_tweet)
      @json = json_tweet
      parse(json_tweet)
    end

    def parse(json_tweet)
      @id = json_tweet["id"].to_s
      @created_at = DateTime.parse(json_tweet["created_at"])
      @text = json_tweet["full_text"]
      @language = json_tweet["lang"]
      @author_id = json_tweet["user"]["id"]

      # A sanity check to make sure we have media in there correctly
      if json_tweet["extended_entities"]&.has_key?("media")
        media_items = json_tweet["extended_entities"]["media"]
      else
        media_items = []
      end

      @image_file_names = media_items.filter_map do |media_item|
        next unless media_item["type"] == "photo"
        Birdsong.retrieve_media(media_item["url"])
      end

      @video_file_names = media_items.filter_map do |media_item|
        next unless (media_item["type"] == "video") || (media_item["type"] == "animated_gif")

        # If the media is video we need to fall back to V1 of the API since V2 doesn't support
        # videos yet. This is dumb, but not a big deal.
        media_url = get_largest_variant_url(media_items)
        media_preview_url = media_items.first["media_url_https"]
        @video_file_type = media_item["type"]

        # We're returning an array because, in the case that someday more videos are available our
        # implementations won't breaks
        [{ url: Birdsong.retrieve_media(media_url), preview_url: Birdsong.retrieve_media(media_preview_url) }]
      end

      # Look up the author given the new id.
      # NOTE: This doesn't *seem* like the right place for this, but I"m not sure where else
      @author = User.lookup(@author_id.to_s).first
    end

    def get_largest_variant_url(media_items)
      # The API response is pretty deeply nested, but this handles that structure
      largest_bitrate_variant = nil
      media_items.each do |media_item|
        # The API returns multiple different resolutions usually. Since we only want to archive
        # the largest we'll run through and find it
        media_item["video_info"]["variants"].each do |variant|
          # Usually there's constant bitrate variants, and sometimes, a .m3u playlist which is for
          # streaming. We want to ignore that one here.
          next unless variant&.keys.include?("bitrate")

          if largest_bitrate_variant.nil? || largest_bitrate_variant["bitrate"] < variant["bitrate"]
            largest_bitrate_variant = variant
          end
        end
      end
      largest_bitrate_variant["url"]
    end

    # Note that unlike the V2 this only supports one url at a time
    def self.retrieve_data_v1(id)
      bearer_token = Birdsong.twitter_bearer_token

      tweet_lookup_url = "https://api.twitter.com/1.1/statuses/show.json?tweet_mode=extended&id=#{id}"

      response = tweet_lookup_v1(tweet_lookup_url, bearer_token)
      raise Birdsong::RateLimitExceeded.new(
        response.headers["x-rate-limit-limit"],
        response.headers["x-rate-limit-remaining"],
        response.headers["x-rate-limit-reset"]
      ) if response.code === 429
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

      raise Birdsong::RateLimitExceeded.new(
        response.headers["x-rate-limit-limit"],
        response.headers["x-rate-limit-remaining"],
        response.headers["x-rate-limit-reset"]
      ) if response.code === 429

      raise Birdsong::NoTweetFoundError, "Tweet with id #{url} not found" if response.code === 404
      if response.code === 403
        json = JSON.parse(response.body)
        if json.has_key?("errors")
          json["errors"].each do |error|
            raise Birdsong::NoTweetFoundError, "User with id #{url} suspended" if error["code"] == 63
          end
        end
      end
      raise Birdsong::AuthorizationError, "Invalid response code #{response.code}" unless response.code === 200

      response
    end


    def self.check_for_errors(parsed_json)
      parsed_json.each do |json|
        next unless json.key?("errors")
        next if json["errors"].empty?

        json["errors"].each do |error|
          # If the tweet is removed, or if the user is suspended you get an Authorization Error
          if error["title"] == "Not Found Error" || error["title"] == "Authorization Error"
            raise Birdsong::NoTweetFoundError, "Tweet with id #{error["value"]} not found"
          end
        end
      end
      false
    end
  end
end
