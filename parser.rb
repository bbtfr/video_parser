require 'selenium/webdriver'
require 'browsermob/proxy'
require 'fileutils'
require 'csv'

ENV["CSV_PATH"] ||= "ml-latest"
ENV["JAVA_HOME"] ||= `/usr/libexec/java_home`.strip
ENV["BrowserMobProxy"] ||= "/usr/local/bin/browsermob-proxy"

movies = CSV.read("#{ENV["CSV_PATH"]}/movies.csv")
movies = movies.select do |movie|
  movie[1] =~ /\(2014\)/
end

links = CSV.read("#{ENV["CSV_PATH"]}/links.csv")
links = movies.map do |movie|
  links.find do |link|
    link[0] == movie[0]
  end
end

imdb_links = links.map do |link|
  "http://www.imdb.com/title/tt#{link[1]}/videogallery"
end

server = BrowserMob::Proxy::Server.new(ENV["BrowserMobProxy"])
server.start

proxy = server.create_proxy

profile = Selenium::WebDriver::Firefox::Profile.new
profile.proxy = proxy.selenium_proxy

client = Selenium::WebDriver::Remote::Http::Default.new
client.timeout = 20

driver = Selenium::WebDriver.for :firefox, :profile => profile, :http_client => client
driver.manage.timeouts.implicit_wait = 3

begin
  FileUtils.mkdir "downloads" rescue nil

  imdb_links.each do |imdb_link|
    imdb_link =~ /\/tt(\d+)/
    imdb_movie_id = $1
    next if File.exists? "downloads/#{imdb_movie_id}"
    FileUtils.mkdir "downloads/#{imdb_movie_id}.wip" rescue nil

    puts "Open Video Gallery Page: #{imdb_link.inspect}."
    driver.navigate.to imdb_link rescue nil

    wait = Selenium::WebDriver::Wait.new timeout: 20
    movie_title = wait.until do
      driver.find_element :css, '.subpage_title_block .parent'
    end
    movie_title = movie_title.text
    puts "Get Page Title: #{movie_title.inspect}."

    wait = Selenium::WebDriver::Wait.new timeout: 20
    search_result_links = wait.until do
      driver.find_elements :css, '.search-results .results-item h2 a'
    end
    search_result_links = search_result_links.map do |search_result_link|
      search_result_link.attribute("href")
    end
    puts "Get Video Pages: #{search_result_links.inspect}."

    File.open "downloads/#{imdb_movie_id}.wip/readme.txt", "w" do |file|
      file.puts movie_title
      file.puts "Video Gallery Page: #{imdb_link}"
      file.puts "Video Pages: \n#{search_result_links.join("\n")}"
    end

    search_result_links.each do |search_result_link|
      search_result_link =~ /\/vi(\d+)/
      imdb_video_id = $1
      next if File.exists? "downloads/#{imdb_movie_id}.wip/#{imdb_video_id}.mp4"

      proxy.new_har
      puts "Open Video Page: #{search_result_link.inspect}."
      driver.navigate.to search_result_link rescue nil

      wait = Selenium::WebDriver::Wait.new timeout: 60
      entry = wait.until do
        proxy.har.entries.find do |entry|
          entry.request.url =~ /video-http.media-imdb.com/
        end
      end

      imdb_video_url = entry.request.url

      wait = Selenium::WebDriver::Wait.new timeout: 20
      video_title = wait.until do
        driver.find_element :css, '#main h1'
      end
      video_title = video_title.text
      puts "Get Video Title: #{video_title.inspect}."

      wait = Selenium::WebDriver::Wait.new timeout: 20
      video_description = wait.until do
        driver.find_element :css, '#main .data-table'
      end
      video_description = video_description.text
      puts "Get Page Description: #{video_description.inspect}."

      File.open "downloads/#{imdb_movie_id}.wip/#{imdb_video_id}.txt", "w" do |file|
        file.puts video_title
        file.puts "Video Page: #{search_result_link}"
        file.puts "Video Link: #{imdb_video_url}"
        file.puts "Video Description: \n#{video_description}"
      end

      puts "Back to Video Gallery Page."
      driver.navigate.back rescue nil

      command = "wget '#{imdb_video_url}' -O 'downloads/#{imdb_movie_id}.wip/#{imdb_video_id}.mp4.wip'"
      puts "Download Video: #{imdb_video_url.inspect}."
      puts "Run: `#{command}`"

      if system command
        FileUtils.mv "downloads/#{imdb_movie_id}.wip/#{imdb_video_id}.mp4.wip",
          "downloads/#{imdb_movie_id}.wip/#{imdb_video_id}.mp4"
      end
    end

    FileUtils.mv "downloads/#{imdb_movie_id}.wip", "downloads/#{imdb_movie_id}"
  end
rescue Exception => e
  puts "#{e.class}: #{e.message}, retry in 10 seconds."
  sleep 10
  retry
ensure
  proxy.close
  driver.quit
end
