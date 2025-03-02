# frozen_string_literal: true

require "capybara/dsl"
require "dotenv/load"
require "oj"
require "selenium-webdriver"
require "logger"
require "securerandom"
require "selenium/webdriver/remote/http/curb"
# require "debug"

# 2022-06-07 14:15:23 WARN Selenium [DEPRECATION] [:browser_options] :options as a parameter for driver initialization is deprecated. Use :capabilities with an Array of value capabilities/options if necessary instead.

options = Selenium::WebDriver::Options.chrome(exclude_switches: ["enable-automation"])
options.add_argument("--start-maximized")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("–-disable-blink-features=AutomationControlled")
options.add_argument("--disable-extensions")
options.add_argument("--enable-features=NetworkService,NetworkServiceInProcess")
options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36")
options.add_preference "password_manager_enabled", false
options.add_argument("--user-data-dir=/tmp/tarun_zorki_#{SecureRandom.uuid}")

Capybara.register_driver :selenium_birdsong do |app|
  client = Selenium::WebDriver::Remote::Http::Curb.new
  # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
end

Capybara.threadsafe = true
Capybara.default_max_wait_time = 60
Capybara.reuse_server = true

module Birdsong
  class Scraper # rubocop:disable Metrics/ClassLength
    include Capybara::DSL

    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::WARN
    @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    @@session_id = nil

    def initialize
      Capybara.default_driver = :selenium_birdsong
    end

    # Instagram uses GraphQL (like most of Facebook I think), and returns an object that actually
    # is used to seed the page. We can just parse this for most things.
    #
    # additional_search_params is a comma seperated keys
    # example: `data,xdt_api__v1__media__shortcode__web_info,items`
    #
    # @returns Hash a ruby hash of the JSON data
    def get_content_of_subpage_from_url(url, subpage_search, additional_search_parameters = nil, &block)
      # So this is fun:
      # For pages marked as misinformation we have to use one method (interception of requrest) and
      # for pages that are not, we can just pull the data straight from the page.
      #
      # How do we figure out which is which?... for now we'll just run through both and see where we
      # go with it.

      # Our user data no longer lives in the graphql object passed initially with the page.
      # Instead it comes in as part of a subsequent call. This intercepts all calls, checks if it's
      # the one we want, and then moves on.
      response_body = nil

      page.driver.browser.intercept do |request, &continue|
        # This passes the request forward unmodified, since we only care about the response
        continue.call(request) && next unless request.url.include?(subpage_search)

        continue.call(request) do |response|
          # Check if not a CORS prefetch and finish up if not
          puts "checking request: #{request.url}"
          puts "for subpage: #{subpage_search}"
          if !response.body.empty? && response.body
            puts "passed"
            check_passed = true
            unless additional_search_parameters.nil?
              puts "checking additional search parameters #{additional_search_parameters}"
              body_to_check = Oj.load(response.body)

              search_parameters = additional_search_parameters.split(",")
              search_parameters.each_with_index do |key, index|
                break if body_to_check.nil?

                check_passed = false unless body_to_check.has_key?(key)
                body_to_check = body_to_check[key]
              end
            end

            unless check_passed == false || !block_given?
              check_passed = block.call(JSON.parse(response.body))
            end

            response_body = response.body if check_passed == true
          end
        end
      rescue Selenium::WebDriver::Error::WebDriverError
        # Eat them
      rescue Birdsong::WebDriverError
      end

      load_saved_cookies
      # Now that the intercept is set up, we visit the page we want
      page.driver.browser.navigate.to(url)
      # We wait until the correct intercept is processed or we've waited 60 seconds
      start_time = Time.now
      # puts "Waiting.... #{url}"

      sleep(rand(10...20))
      while response_body.nil? && (Time.now - start_time) < 60
        sleep(0.1)
      end

      # if response_body.nil?
      #   puts "Logging in and refreshing"
      #   login
      #   sleep(rand(5..10))
      #   page.driver.browser.navigate.to(url)

      #   start_time = Time.now
      #   sleep(rand(10...20))
      #   while response_body.nil? && (Time.now - start_time) < 60
      #     sleep(0.1)
      #   end
      # end

      page.driver.execute_script("window.stop();")
      save_cookies

      raise Birdsong::NoTweetFoundError if response_body.nil?
      Oj.load(response_body)
    rescue Birdsong::WebDriverError
    end

  private

    ##########
    # Set the session to use a new user folder in the options!
    # #####################
    def reset_selenium
      options = Selenium::WebDriver::Options.chrome(exclude_switches: ["enable-automation"])
      options.add_argument("--start-maximized")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("–-disable-blink-features=AutomationControlled")
      options.add_argument("--disable-extensions")
      options.add_argument("--enable-features=NetworkService,NetworkServiceInProcess")

      options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36")
      options.add_preference "password_manager_enabled", false
      options.add_argument("--user-data-dir=/tmp/tarun_zorki_#{SecureRandom.uuid}")
      # options.add_argument("--user-data-dir=/tmp/tarun")

      Capybara.register_driver :selenium do |app|
        client = Selenium::WebDriver::Remote::Http::Curb.new
        # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
      end

      Capybara.current_driver = :selenium
    end

    def is_logged_in?(id = nil)
      load_saved_cookies
      # Check if we're on a Twitter page already, if not visit it.
      if id.nil?
        page.driver.browser.navigate.to("https://x.com")
      else
        page.driver.browser.navigate.to("https://x.com/jack/status/#{id}") # We may be logged in already?
      end

      # unless page.driver.browser.current_url.include?("twitter.com") || page.driver.browser.current_url.include?("x.com")
      #   # There seems to be a bug in the Linux ARM64 version of chromedriver where this will properly
      #   # navigate but then timeout, crashing it all up. So instead we check and raise the error when
      #   # that then fails again.
      #   if id.nil?
      #     page.driver.browser.navigate.to("https://x.com")
      #   else
      #     page.driver.browser.navigate.to("https://x.com/jack/status/#{id}") # We may be logged in already?
      #   end
      # end

      # We don't have to login if we already are
      begin
        return true if find_field("Search", wait: 10)
      rescue Capybara::ElementNotFound; end

      false
    end

    def login
      # Reset the sessions so that there's nothing laying around
      page.quit

      # If we already have files, do it
      return if is_logged_in?

      page.driver.browser.find_element(link_text: "Sign in").click      # Check if we're redirected to a login page, if we aren't we're already logged in

      # return unless page.has_xpath?('//*[@id="loginForm"]/div/div[3]/button')

      # Try to log in
      loop_count = 0
      while loop_count < 5 do
        3.times do
          sleep(rand * 8.8)
          element = page.driver.browser.find_element(tag_name: "input", name: "text")
          next if element.nil?
          element.click
          break
        rescue StandardError => e
          puts e
          next
        end

        sleep(rand * 2.8)
        fill_in("text", with: ENV["TWITTER_USER_NAME"])
        sleep(rand * 2.8)
        find_button("Next").click
        sleep(rand * 2.1)
        fill_in("password", with: ENV["TWITTER_PASSWORD"])

        begin
          click_button("Log in", exact_text: true) # Note: "Log in" (lowercase `in`) instead redirects to Facebook's login page
        rescue Capybara::ElementNotFound; end # If we can't find it don't break horribly, just keep waiting

        break unless has_css?('p[data-testid="login-error-message"', wait: 10)
        loop_count += 1
        sleep(rand * 10.3)
      end

      # Sometimes Twitter just... doesn't let you log in
      raise "Twitter not accessible" if loop_count == 5

      # Save the logged in cookies for restoring later
      save_cookies
      # No we don't want to save our login credentials
      begin
        click_on("Save Info")
      rescue Capybara::ElementNotFound; end
    end

    def logout
      page.driver.browser.navigate.to("https://x.com/logout")
      click_button("Log out", exact_text: true)
    end

    def fetch_image(url)
      request = Typhoeus::Request.new(url, followlocation: true)
      request.on_complete do |response|
        if request.success?
          return request.body
        elsif request.timed_out?
          raise Zorki::Error("Fetching image at #{url} timed out")
        else
          raise Zorki::Error("Fetching image at #{url} returned non-successful HTTP server response #{request.code}")
        end
      end
    end

    # Convert a string to an integer
    def number_string_to_integer(number_string)
      # First we have to remove any commas in the number or else it all breaks
      number_string = number_string.delete(",")
      # Is the last digit not a number? If so, we're going to have to multiply it by some multiplier
      should_expand = /[0-9]/.match(number_string[-1, 1]).nil?

      # Get the last index and remove the letter at the end if we should expand
      last_index = should_expand ? number_string.length - 1 : number_string.length
      number = number_string[0, last_index].to_f
      multiplier = 1
      # Determine the multiplier depending on the letter indicated
      case number_string[-1, 1]
      when "m"
        multiplier = 1_000_000
      end

      # Multiply everything and insure we get an integer back
      (number * multiplier).to_i
    end

    def save_cookies
      cookies_json = page.driver.browser.manage.all_cookies.to_json
      File.write("birdsong_cookies.json", cookies_json)
    end

    def load_saved_cookies
      return unless File.exist?("birdsong_cookies.json")
      page.driver.browser.navigate.to("https://x.com")

      cookies_json = File.read("birdsong_cookies.json")
      cookies = JSON.parse(cookies_json, symbolize_names: true)
      cookies.each do |cookie|
        cookie[:expires] = Time.parse(cookie[:expires]) unless cookie[:expires].nil?
        begin
          page.driver.browser.manage.add_cookie(cookie)
        rescue StandardError
        end
      end
    end
  end
end

# require_relative "tweet_scraper"
