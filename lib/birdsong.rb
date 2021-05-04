# frozen_string_literal: true

require "json"
require "typhoeus"
require "date"
require "uri"
require "byebug"

require_relative "birdsong/version"
require_relative "birdsong/tweet"
require_relative "birdsong/user"

module Birdsong
  class Error < StandardError; end
  class AuthorizationError < Error; end
  class InvalidIdError < Error; end

  # The general fields to always return for Users
  def self.user_fields
    "name,created_at,location,profile_image_url,protected,public_metrics,url,username,verified,withheld,description"
  end

  # The general fields to always return for Tweets
  def self.tweet_fields
    "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang"
  end
end
