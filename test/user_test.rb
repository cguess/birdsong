# frozen_string_literal: true

require "test_helper"
require "date"

class UserTest < Minitest::Test
  def test_that_a_user_is_created_with_id
    tweets = Birdsong::User.lookup("404661154")
    tweets.each { |user| assert_instance_of Birdsong::User, user }
  end

  def test_that_a_user_raises_exception_with_invalid_id
    assert_raises Birdsong::InvalidIdError do
      Birdsong::User.lookup("abcdef")
    end
  end

  def test_that_a_tweet_has_correct_attributes
    user = Birdsong::User.lookup("404661154").first
    assert_equal user.id, "404661154"
    assert_equal user.created_at, DateTime.parse("2011-11-04T07:18:35.000Z")
    assert_equal user.profile_image_url, URI("https://pbs.twimg.com/profile_images/1140973306889277440/q3P0CIh6_normal.jpg")
    assert_equal user.name, "Frederik Obermaier"
    assert_equal user.location, "Threema FPN4FKZE  | PGP"
  end

   def test_that_a_tweet_cant_be_found_works
    tweet = Birdsong::User.lookup("abcdef")
    assert tweet.empty?
  end
end
