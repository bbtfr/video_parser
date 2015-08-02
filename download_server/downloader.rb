require 'selenium/webdriver'
require 'browsermob/proxy'
require 'fileutils'
require 'yaml'

ENV["JAVA_HOME"] ||= `/usr/libexec/java_home`.strip
ENV["BROWSER_MOB_PROXY"] ||= "/usr/local/bin/browsermob-proxy"
ENV["DOWNLOADS"] ||= "downloads.yml"

GALLERY = YAML.load(File.read(ENV["DOWNLOADS"])) || []

def retry_five_times items, &block
  items.each do |*args|
    retries = 0
    begin
      block.call *args
    rescue Interrupt
      raise
    rescue Exception => e
      retries += 1
      if retries > 3
        puts "#{e.class}: #{e.message}, retried 3 times, ignore and go next."
        next
      else
        puts "#{e.class}: #{e.message}, retry ##{retries}."
        retry
      end
    end
  end
end

server = BrowserMob::Proxy::Server.new(ENV["BROWSER_MOB_PROXY"])
server.start

proxy = server.create_proxy

client = Selenium::WebDriver::Remote::Http::Default.new
client.timeout = 20

driver = Selenium::WebDriver.for :chrome, :http_client => client, proxy: proxy.selenium_proxy

print "Press Enter to continue..."
gets

begin
  FileUtils.mkdir "downloads" rescue nil

  retry_five_times GALLERY do |gallery|
    movie_id = gallery["id"]
    next if File.exists? "downloads/#{movie_id}"
    FileUtils.mkdir "downloads/#{movie_id}.wip" rescue nil

    retry_five_times gallery["videos"] do |video|
      video_id = video["id"]
      video_link = video["link"]
      next if File.exists? "downloads/#{movie_id}.wip/#{video_id}.mp4"

      proxy.new_har
      puts "Open Video Page: #{video_link.inspect}."
      begin
        driver.navigate.to video_link
      rescue => e
        puts e.class, e.message
      end

      puts "Parse Video Link from requests."
      wait = Selenium::WebDriver::Wait.new timeout: 20
      entry = wait.until do
        proxy.har.entries.find do |entry|
          entry.request.url =~ /\.mp4|\.m3u8/
        end
      end

      video_url = entry.request.url
      filename = "downloads/#{movie_id}.wip/#{video_id}.mp4.wip"

      if video_url =~ /\.mp4/
        command = "wget '#{video_url}' -c -O '#{filename}'"
        puts "Download Video: #{video_url.inspect}."
        puts "Run: `#{command}`"

        # if system command
        #   FileUtils.mv "downloads/#{movie_id}.wip/#{video_id}.mp4.wip",
        #     "downloads/#{movie_id}.wip/#{video_id}.mp4"
        # end
      elsif video_url =~ /\.m3u8/
        command = "ffmpeg -i '#{video_url}' -y -acodec copy -vcodec copy -f mp4 '#{filename}'"
        puts "Download Video: #{video_url.inspect}."
        puts "Run: `#{command}`"

        # if system command
        #   FileUtils.mv "downloads/#{movie_id}.wip/#{video_id}.mp4.wip",
        #     "downloads/#{movie_id}.wip/#{video_id}.mp4"
        # end
      end
    end

    FileUtils.mv "downloads/#{movie_id}.wip", "downloads/#{movie_id}"
  end
rescue Interrupt
  exit
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  proxy.close
  driver.quit
end
