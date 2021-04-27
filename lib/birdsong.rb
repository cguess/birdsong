# frozen_string_literal: true

require "json"
require "typhoeus"
require "date"

require_relative "birdsong/version"
require_relative "birdsong/tweet"

module Birdsong
  class Error < StandardError; end
end
