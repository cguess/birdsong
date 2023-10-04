# frozen_string_literal: true

module Birdsong
  class Tweet
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      tweet_objects = ids.map { |id| Birdsong::TweetScraper.new.parse(id) }

      tweet_objects.map do |tweet_object|
        Tweet.new(tweet_object)
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
    attr_reader :video_preview_image

    alias_method :user, :author # Every other gem uses `user` so we can just alias it

  private

    def initialize(tweet_object)
      @id = tweet_object[:id]
      @created_at = DateTime.parse(tweet_object[:date])
      @text = tweet_object[:text]
      @language = tweet_object[:language]
      @author_id = tweet_object[:user][:id]

      @image_file_names = tweet_object[:images]
      @video_file_names = tweet_object[:video]
      @video_file_type = tweet_object[:video_file_type]
      @video_preview_image = tweet_object[:video_preview_image]
      # Look up the author given the new id.
      # NOTE: This doesn't *seem* like the right place for this, but I"m not sure where else
      @author = User.new(tweet_object[:user])
    end
  end
end
