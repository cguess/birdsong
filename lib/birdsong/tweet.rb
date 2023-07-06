# frozen_string_literal: true

require "URI"

module Birdsong
  class Tweet
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      json_response = self.retrieve_data_oembed(ids)
      [Tweet.new(json_response, ids.first)]
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

    def initialize(json_tweet, id)
      @json = json_tweet
      parse(json_tweet, id)
    end

# {"__typename"=>"Tweet",
# "lang"=>"en",
# "favorite_count"=>192013,
# "created_at"=>"2006-03-21T20:50:14.000Z",
# "display_text_range"=>[0, 24],
# "entities"=>{"hashtags"=>[], "urls"=>[], "user_mentions"=>[], "symbols"=>[]},
# "id_str"=>"20",
# "text"=>"just setting up my twttr",
# "user"=>
#  {"id_str"=>"12",
#   "name"=>"jack",
#   "profile_image_url_https"=>"https://pbs.twimg.com/profile_images/1661201415899951105/azNjKOSH_normal.jpg",
#   "screen_name"=>"jack",
#   "verified"=>false,
#   "is_blue_verified"=>true,
#   "profile_image_shape"=>"Circle"},
# "edit_control"=>
#  {"edit_tweet_ids"=>["20"], "editable_until_msecs"=>"1142976014000", "is_edit_eligible"=>true, "edits_remaining"=>"5"},
# "conversation_count"=>11873,
# "news_action_type"=>"conversation",
# "isEdited"=>false,
# "isStaleEdit"=>false}

    def parse(json_tweet, id)
      @id = json_tweet["id"]
      @created_at = DateTime.parse(json_tweet["created_at"])
      @text = json_tweet["text"]
      @image_file_names = []
      @video_file_names = []

      # @language = json_tweet["lang"]

      # Parse the profile_image_url_https and pull the author_id from the url
      image_uri = URI(json_tweet["user"]["profile_image_url_https"])
      @author_id = image_uri.path.split("/")[2]

      media_items = json_tweet["mediaDetails"]

      return if media_items.nil?

      media_items = media_items.first
      # Check if it's a video or image/images
      if !media_items.has_key?("video_info")
        @image_file_names = [media_items["media_url_https"]]
        Birdsong.retrieve_media(@image_file_names.first)
        # TODO: add support for slideshows here
        # @image_file_names = media_items.filter_map do |media_item|
        #   debugger
        #   url = media_item["media_url_https"]
        #   Birdsong.retrieve_media(url)
        # end
      else
        largest_variant = get_largest_variant(media_items)

        unless largest_variant.nil?
          media_url = largest_variant["url"]
          media_preview_url = media_items["media_url_https"]
          @video_file_type = largest_variant["content_type"].split("/").first

          @video_file_names = [[{ url: Birdsong.retrieve_media(media_url),
                                 preview_url: Birdsong.retrieve_media(media_preview_url) }]]
        end
      end

      # Look up the author given the new id.
      # NOTE: This doesn't *seem* like the right place for this, but I"m not sure where else
      # @author = User.lookup(@author_id).first
    end

    def get_largest_variant(media_items)
      # The API response is pretty deeply nested, but this handles that structure
      largest_bitrate_variant = nil
      # The API returns multiple different resolutions usually. Since we only want to archive
      # the largest we'll run through and find it
      media_items["video_info"]["variants"].each do |variant|
        # Usually there's constant bitrate variants, and sometimes, a .m3u playlist which is for
        # streaming. We want to ignore that one here.
        next unless variant&.keys.include?("bitrate")

        if largest_bitrate_variant.nil? || largest_bitrate_variant["bitrate"] < variant["bitrate"]
          largest_bitrate_variant = variant
        end
      end
      largest_bitrate_variant
    end

    def self.retrieve_data_oembed(ids)
      id = ids.first
      cdn_url = "cdn.syndication.twimg.com/tweet-result"
      response = Typhoeus.get(cdn_url, params: { id: id }, followlocation: true)

      raise Birdsong::NoTweetFoundError, "Tweet with id #{id} not found" unless response.code == 200

      begin
        json_response = JSON.parse(response.body)
      rescue JSON::ParserError
        # Twitter returns HTML if there's no tweet
        raise Birdsong::NoTweetFoundError, "Tweet with id #{id} not found"
      end

      json_response["id"] = id
      json_response
    end

    def self.check_for_errors(parsed_json)
      return false unless parsed_json.key?("errors")
      return false if parsed_json["errors"].empty?

      parsed_json["errors"].each do |error|
        # If the tweet is removed, or if the user is suspended you get an Authorization Error
        if error["title"] == "Not Found Error" || error["title"] == "Authorization Error"
          raise Birdsong::NoTweetFoundError, "Tweet with id #{error["value"]} not found"
        end
      end
      false
    end
  end
end
