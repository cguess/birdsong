# frozen_string_literal: true

require "test_helper"
require "date"

class UserTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_that_a_user_is_created_with_id
    tweets = Birdsong::User.lookup("404661154")
    tweets.each { |user| assert_instance_of Birdsong::User, user }
  end

  def test_that_a_user_raises_exception_with_invalid_id
    assert_raises Birdsong::InvalidIdError do
      Birdsong::User.lookup("abcdef")
    end
  end

  # This could break if Frederik ever changes his info. That's probably the reason if this is failing
  def test_that_a_tweet_has_correct_attributes
    user = Birdsong::User.lookup("404661154").first
    assert_equal user.id, "404661154"
    assert_equal user.created_at, DateTime.parse("2011-11-04T07:18:35.000Z")
    assert_equal user.profile_image_url, "https://pbs.twimg.com/profile_images/1140973306889277440/q3P0CIh6_normal.jpg"
    assert_equal user.name, "Frederik Obermaier"
    assert_equal user.username, "f_obermaier"
    assert_equal user.location, "Threema FPN4FKZE  | PGP"
    assert_equal user.profile_image_url, "https://pbs.twimg.com/profile_images/1140973306889277440/q3P0CIh6_normal.jpg"
    assert_equal user.description, "investigative journalist | pulitzer prize | received w @b_obermayer the @PanamaPapers #StracheVideo | deputy @sz_investigativ | @icijorg @acdatacollectiv"
    assert_equal user.url, "http://www.frederikobermaier.com"
    assert_kind_of Integer, user.followers_count
    assert_kind_of Integer, user.following_count
    assert_kind_of Integer, user.tweet_count
    assert_kind_of Integer, user.listed_count
    assert user.verified
    assert user.profile_image_file_name.empty? == false

    # Make sure the file is created properly
    assert File.exist?(user.profile_image_file_name) && File.file?(user.profile_image_file_name)
  end
end
