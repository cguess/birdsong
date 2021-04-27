# frozen_string_literal: true

require "test_helper"

class BirdsongTest < Minitest::Test
  def test_that_it_has_a_version_number
    assert_same ::Birdsong::VERSION.nil?, false
  end
end
