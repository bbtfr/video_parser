require 'yaml'

ENV["DOWNLOADS"] ||= "downloads.yml"
ENV["DOWNLOAD_DIR"] ||= "/Users/amber/Downloads/"

GALLERY = YAML.load(File.read(ENV["DOWNLOADS"])) || []

links = GALLERY.map do |gallery|
  gallery["videos"].map do |video|
    video["link"]
  end
end.flatten

links -= Dir["#{ENV["DOWNLOAD_DIR"]}/*.url"].map do |file|
  File.read file
end

puts links
