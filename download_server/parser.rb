require 'nokogiri'
require 'open-uri'
require 'yaml'
require 'csv'

ENV["CSV_DIR"] ||= "ml-latest"
ENV["DOWNLOADS_YAML"] ||= "downloads.yml"
ENV["MOVIE_PATTERN"] ||= "\(2014\)"

class String
  def cleanup
    self.strip.gsub(/\s+/, " ")
  end

  def parameterize
    self.downcase.gsub(/\s+/, "_")[/[a-z_]*/]
  end
end

GALLERY = YAML.load(File.read(ENV["DOWNLOADS_YAML"])) || []
MOVIE_PATTERN = Regexp.new ENV["MOVIE_PATTERN"]

begin
  movies = CSV.read("#{ENV["CSV_DIR"]}/movies.csv")
  movies = movies.select do |movie|
    movie[1] =~ MOVIE_PATTERN
  end

  links = CSV.read("#{ENV["CSV_DIR"]}/links.csv")
  links = movies.map do |movie|
    links.find do |link|
      link[0] == movie[0]
    end
  end

  gallery_links = links.map do |link|
    "http://www.imdb.com/title/tt#{link[1]}/videogallery"
  end - GALLERY.map do |gallery|
    gallery["link"]
  end

  gallery_links.each do |gallery_link|
    puts "Parse Video Gallery Page: #{gallery_link}"
    doc = Nokogiri::HTML(open(gallery_link))
    video_links = doc.css(".search-results .results-item h2 a").map do |a|
      "http://www.imdb.com#{a.attr("href")}"
    end
    puts "Get Video Pages: #{video_links.inspect}."
    gallery = Hash.new
    gallery_link =~ /\/tt(\d+)/
    gallery["id"] = $1.to_i
    gallery["link"] = gallery_link
    gallery["title"] = doc.css(".parent").text.cleanup
    gallery["videos"] = video_links.map do |video_link|
      video_link =~ /\/vi(\d+)/
      video = Hash.new
      video["id"] = $1.to_i
      video["link"] = video_link
      video
    end
    GALLERY << gallery
  end

  videos = GALLERY.map do |gallery|
    gallery["videos"].reject do |video|
      video["title"]
    end
  end.flatten

  videos.each do |video|
    video_link = video["link"]
    puts "Parse Video Page: #{video_link}"
    doc = Nokogiri::HTML(open(video_link))
    doc.css("#video-details tr").each do |tr|
      key = tr.css("td:first-child").text.parameterize
      value = tr.css("td:last-child").text.strip
      video[key] = value
    end
    video["title"] ||= doc.css("#main h1").text.cleanup.gsub(/\(\d+\)\s+/, "")
    video.delete "video_url"
  end
rescue Interrupt
  exit
rescue => e
  raise e
ensure
  File.write "downloads.yml", GALLERY.to_yaml
end
