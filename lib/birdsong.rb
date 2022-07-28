# frozen_string_literal: true

require "json"
require "typhoeus"
require "date"
require "byebug"
require "securerandom"
require "helpers/configuration"
require "fileutils"

require_relative "birdsong/version"
require_relative "birdsong/tweet"
require_relative "birdsong/user"

module Birdsong
  extend Configuration

  class Error < StandardError; end
  class AuthorizationError < Error; end
  class InvalidIdError < Error; end
  class InvalidMediaTypeError < Error; end
  class NoTweetFoundError < Error; end

  define_setting :temp_storage_location, "tmp/birdsong"

  # The general fields to always return for Users
  def self.user_fields
    "name,created_at,location,profile_image_url,protected,public_metrics,url,username,verified,withheld,description"
  end

  # The general fields to always return for Tweets
  def self.tweet_fields
    "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang"
  end

  # Get media from a URL and save to a temp folder set in the configuration under
  # temp_storage_location
  def self.retrieve_media(url)
    response = Typhoeus.get(url)

    # Get the file extension if it's in the file
    extension = url.split(".").last

    # Do some basic checks so we just empty out if there's something weird in the file extension
    # that could do some harm.
    if extension.length.positive?
      extension = extension[0...extension.index("?")]
      extension = nil unless /^[a-zA-Z0-9]+$/.match?(extension)
      extension = ".#{extension}" unless extension.nil?
    end

    temp_file_name = "#{Birdsong.temp_storage_location}/#{SecureRandom.uuid}#{extension}"

    # We do this in case the folder isn't created yet, since it's a temp folder we'll just do so
    self.create_temp_storage_location
    File.binwrite(temp_file_name, response.body)
    temp_file_name
  end

private

  def self.create_temp_storage_location
    return if File.exist?(Birdsong.temp_storage_location) && File.directory?(Birdsong.temp_storage_location)
    FileUtils.mkdir_p Birdsong.temp_storage_location
  end
end
