# frozen_string_literal: true

require "typhoeus"
require_relative "scraper"

module Birdsong
  class TweetScraper < Scraper
    def parse(id)
      # Stuff we need to get from the DOM (implemented is starred):
      # - User *
      # - Text *
      # - Image * / Images * / Video *
      # - Date *
      # - Number of likes *
      # - Hashtags

      Capybara.app_host = "https://x.com"

      # video slideshows https://www.instagram.com/p/CY7KxwYOFBS/?utm_source=ig_embed&utm_campaign=loading
      # login
      graphql_object = get_content_of_subpage_from_url(
        "https://x.com/jack/status/#{id}",
        "/graphql",
        "data,tweetResult,result"
      )

      graphql_object = graphql_object.first if graphql_object.kind_of?(Array)
      graphql_object = graphql_object["data"]["tweetResult"]["result"]

      if graphql_object.key?("__typename") && graphql_object["__typename"] == "TweetUnavailable"
        raise Birdsong::NoTweetFoundError
      end

      text = graphql_object["legacy"]["full_text"]
      date = graphql_object["legacy"]["created_at"]
      id   = graphql_object["legacy"]["id_str"]
      number_of_likes = graphql_object["legacy"]["favorite_count"]
      language = graphql_object["legacy"]["lang"]

      images = []
      videos = []
      video_preview_image = nil
      video_file_type = nil

      if graphql_object["legacy"]["entities"].key?("media")
        graphql_object["legacy"]["entities"]["media"].each do |media|
          case media["type"]
          when "photo"
            images << Birdsong.retrieve_media(media["media_url_https"])
          when "video"
            video_preview_image = Birdsong.retrieve_media(media["media_url_https"])
            video_variants = media["video_info"]["variants"]
            largest_bitrate_variant = video_variants.sort_by do |variant|
              variant["bitrate"].nil? ? 0 : variant["bitrate"]
            end.last

            videos << Birdsong.retrieve_media(largest_bitrate_variant["url"])
            video_file_type = "video"
          when "animated_gif"
            video_preview_image = Birdsong.retrieve_media(media["media_url_https"])
            videos << media["video_info"]["variants"].first["url"]
            video_file_type = "animated_gif"
          end
        end
      end

      screenshot_file = take_screenshot()

      # This has to run last since it switches pages
      user_object = graphql_object["core"]["user_results"]["result"]
      user = {
        id: user_object["id"],
        name: user_object["legacy"]["name"],
        username: user_object["legacy"]["screen_name"],
        sign_up_date: user_object["legacy"]["created_at"],
        location: user_object["legacy"]["location"],
        profile_image_url: user_object["legacy"]["profile_image_url_https"],
        description: user_object["legacy"]["description"],
        followers_count: user_object["legacy"]["followers_count"],
        following_count: user_object["legacy"]["friends_count"],
        tweet_count: user_object["legacy"]["statuses_count"],
        listed_count: user_object["legacy"]["listed_count"],
        verified: user_object["legacy"]["verified"],
        url: user_object["legacy"]["url"],
        profile_image_file_name: Birdsong.retrieve_media(user_object["legacy"]["profile_image_url_https"])
      }

      page.quit

      {
        images: images,
        video: videos,
        video_preview_image: video_preview_image,
        screenshot_file: screenshot_file,
        text: text,
        date: date,
        number_of_likes: number_of_likes,
        user: user,
        id: id,
        language: language,
        video_file_type: video_file_type
      }
    end

    def take_screenshot
      # First check if a post has a fact check overlay, if so, clear it.
      # The only issue is that this can take *awhile* to search. Not sure what to do about that
      # since it's Instagram's fault for having such a fucked up obfuscated hierarchy      # Take the screenshot and return it
      save_screenshot("#{Birdsong.temp_storage_location}/instagram_screenshot_#{SecureRandom.uuid}.png")
    end
  end
end
