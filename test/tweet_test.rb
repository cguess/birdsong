# frozen_string_literal: true

require "test_helper"
require "date"
require "debug"

class TweetTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_that_a_tweet_is_created_with_id
    tweets = Birdsong::Tweet.lookup("1378268627615543296")
    tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
  end

  # def test_that_a_tweet_with_a_nil_author_url_is_recreated
  #   tweets = Birdsong::Tweet.lookup("1651942285620256772")

  #   # This tweet's author url should not be nil anymore
  #   tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
  #   tweets.each { |tweet| assert_not_nil tweet.author.url }
  # end

  def test_that_a_tweet_raises_exception_with_invalid_id
    assert_raises Birdsong::InvalidIdError do
      Birdsong::Tweet.lookup("abcdef")
    end
  end

  # def test_that_a_tweet_has_correct_attributes
  #   tweet = Birdsong::Tweet.lookup("1378268627615543296").first
  #   assert_equal tweet.id, "1378268627615543296"
  #   assert_equal tweet.created_at, DateTime.parse("2021-04-03T08:50:22.000Z")
  #   assert_equal tweet.text, "Five years ago... #PanamaPapers #OnThisDay @ICIJorg @SZ https://t.co/hLMVuYOk3D https://t.co/8uJkbb6Pko"
  #   assert_equal tweet.language, "en"
  #   assert_equal tweet.author.name, "Frederik Obermaier"
  # end

  def test_that_a_tweet_cant_be_found_works
    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup("19")
    end
  end

  def test_that_a_tweet_can_have_no_media
    tweet = Birdsong::Tweet.lookup("20").first
    assert_equal tweet.id, "20"
    assert_not_nil tweet.image_file_names
    assert_equal 0, tweet.image_file_names.count
    assert_equal 0, tweet.video_file_names.count
  end

  def test_that_a_tweet_can_have_a_single_image
    tweet = Birdsong::Tweet.lookup("1407341650737762304").first
    assert_not_nil tweet.image_file_names
    assert_equal 1, tweet.image_file_names.count
    assert_equal 0, tweet.video_file_names.count
  end

  # def test_that_a_tweet_can_have_a_slideshow
  #   tweet = Birdsong::Tweet.lookup("1407322444399099904").first
  #   assert_not_nil tweet.image_file_names
  #   assert_equal 4, tweet.image_file_names.count
  #   assert_equal 0, tweet.video_file_names.count
  # end

  def test_that_a_tweet_can_have_a_video
    tweet = Birdsong::Tweet.lookup("1407342630837657605").first
    assert_not_nil tweet.video_file_names
    assert_equal 1, tweet.video_file_names.count
    assert_equal 0, tweet.image_file_names.count
    assert_equal "video", tweet.video_file_type
  end

  def test_that_a_tweet_can_have_a_video_preview
    tweet = Birdsong::Tweet.lookup("1407342630837657605").first
    assert_not_nil tweet.video_file_names.first.first[:preview_url]
  end

  def test_that_a_tweet_handles_no_variants_for_video
    tweet = Birdsong::Tweet.lookup("1258817692448051200").first
    assert_not_nil tweet.video_file_names
    assert_equal 1, tweet.video_file_names.count
    assert_equal 0, tweet.image_file_names.count
  end

  def test_that_a_tweet_can_have_a_gif
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert_not_nil tweet.video_file_names
    assert_equal 0, tweet.image_file_names.count
    assert_equal 1, tweet.video_file_names.count
    assert_equal "video", tweet.video_file_type
  end

  def test_that_a_tweet_can_have_a_gif_preview
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert_not_nil tweet.video_file_names.first.first[:preview_url]
  end

  # def test_that_user_aliases_author
  #   tweet = Birdsong::Tweet.lookup("1472873480249131012").first
  #   assert_equal tweet.author, tweet.user
  # end

  def test_that_a_tweet_with_a_suspended_author_works
    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup("1329846849210114052").first
    end
  end
end
