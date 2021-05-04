# frozen_string_literal: true

require "test_helper"
require "date"

class TweetTest < Minitest::Test
  def test_that_a_tweet_is_created_with_id
    tweets = Birdsong::Tweet.lookup("1378268627615543296")
    tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
  end

  def test_that_a_tweet_raises_exception_with_invalid_id
    assert_raises Birdsong::InvalidIdError do
      Birdsong::Tweet.lookup("abcdef")
    end
  end

  def test_that_a_tweet_has_correct_attributes
    tweet = Birdsong::Tweet.lookup("1378268627615543296").first
    assert_equal tweet.id, "1378268627615543296"
    assert_equal tweet.created_at, DateTime.parse("2021-04-03T08:50:22.000Z")
    assert_equal tweet.text, "Five years ago... #PanamaPapers #OnThisDay @ICIJorg @SZ https://t.co/hLMVuYOk3D https://t.co/8uJkbb6Pko"
    assert_equal tweet.language, "en"
  end
end
