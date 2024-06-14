# frozen_string_literal: true

# A note: Some of these will fail non-deterministically. This is because Twitter/X is a shit show and
# their servers fail all the time. In that case, we just throw an error which should be caught
# (going to usually be Selenium::WebDriver::Error::NoSuchElementError) by whatever is using this library
# and retry later.

require "test_helper"
require "date"

class TweetTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_that_a_tweet_is_created_with_id
    tweets = Birdsong::Tweet.lookup("1378268627615543296")
    assert_not_nil tweets
    assert_equal 1, tweets.count
    tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
  end

  def test_that_a_tweet_with_a_nil_author_url_is_recreated
    tweets = Birdsong::Tweet.lookup("1651942285620256772")

    # This tweet's author url should not be nil anymore
    tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
    tweets.each { |tweet| assert_not_nil tweet.author.url }
  end

  def test_that_a_tweet_raises_exception_with_invalid_id
    assert_raises Birdsong::InvalidIdError do
      Birdsong::Tweet.lookup("abcdef")
    end
  end

  def test_that_a_tweet_has_correct_attributes
    tweet = Birdsong::Tweet.lookup("1378268627615543296").first
    assert_equal "1378268627615543296", tweet.id
    assert_equal DateTime.parse("2021-04-03T08:50:22.000Z"), tweet.created_at
    assert_equal "Five years ago... #PanamaPapers #OnThisDay @ICIJorg @SZ https://t.co/hLMVuYOk3D https://t.co/8uJkbb6Pko", tweet.text
    assert_equal "en", tweet.language
    assert_equal "Frederik Obermaier", tweet.author.name
  end

  def test_that_a_tweet_cant_be_found_works
    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup("19")
    end
  end

  def test_that_a_tweet_can_have_no_media
    tweet = Birdsong::Tweet.lookup("20").first
    assert_equal "20", tweet.id
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

  def test_that_a_tweet_can_have_a_slideshow
    tweet = Birdsong::Tweet.lookup("1407322444399099904").first
    assert_not_nil tweet.image_file_names
    assert_equal 4, tweet.image_file_names.count
    assert_equal 0, tweet.video_file_names.count
  end

  def test_that_a_tweet_can_have_a_video
    tweet = Birdsong::Tweet.lookup("1407342630837657605").first
    assert_not_nil tweet.video_file_names
    assert_equal 1, tweet.video_file_names.count
    assert_equal 0, tweet.image_file_names.count
    assert_equal "video", tweet.video_file_type
  end

  def test_that_a_tweet_can_have_a_video_preview
    tweet = Birdsong::Tweet.lookup("1407342630837657605").first
    assert_not_nil tweet.video_preview_image
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
    assert_equal "animated_gif", tweet.video_file_type
  end

  def test_that_a_tweet_can_have_a_gif_preview
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert_not_nil tweet.video_preview_image
  end

  def test_that_user_aliases_author
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert_equal tweet.author, tweet.user
  end

  def test_that_a_tweet_with_a_suspended_author_fails
    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup("1329846849210114052").first
    end
  end

  def test_another_url
    Birdsong::Tweet.lookup("1552221138037755904")
  end

  def test_another_url_2
    Birdsong::Tweet.lookup("1775419979871162733")
  end
end
