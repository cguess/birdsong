# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "birdsong"

require "minitest/autorun"

def cleanup_temp_folder
  # Delete the temp folder that'll be created here
  if File.exist?("tmp") && File.directory?("tmp")
    FileUtils.rm_r "tmp"
  end
end
