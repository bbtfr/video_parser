require 'fileutils'
require 'yaml'

ENV["DOWNLOADS_YAML"] ||= "downloads.yml"
ENV["DOWNLOAD_DIR"] ||= "downloads"
ENV["MOVIE_PATTERN"] ||= "[Tt]railer|[Cc]lip"

GALLERY = YAML.load(File.read(ENV["DOWNLOADS_YAML"])) || []
MOVIE_PATTERN = Regexp.new ENV["MOVIE_PATTERN"]
MAPPER = {}

GALLERY.each do |gallery|
  gallery["videos"].each do |video|
    next unless video["title"] =~ MOVIE_PATTERN
    MAPPER[video["link"]] = [gallery["id"], video["id"]]
  end
end

Dir["#{ENV["DOWNLOAD_DIR"]}/*.url"].each do |file|
  url = File.read(file).strip
  gallery_id, video_id = MAPPER[url]
  next unless gallery_id && video_id
  FileUtils.mkdir "#{ENV["DOWNLOAD_DIR"]}/#{gallery_id}" rescue nil
  video = file.sub(".url", "")
  next unless File.exists? video
  dest = "#{ENV["DOWNLOAD_DIR"]}/#{gallery_id}/#{video_id}#{File.extname(video)}"
  puts "Move #{video.inspect} to #{dest.inspect}"
  FileUtils.mv video, dest
end
