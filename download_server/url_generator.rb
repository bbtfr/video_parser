require 'yaml'

ENV["DOWNLOADS_YAML"] ||= "downloads.yml"
ENV["DOWNLOAD_DIR"] ||= "downloads"
ENV["MOVIE_PATTERN"] ||= "[Tt]railer|[Cc]lip"

GALLERY = YAML.load(File.read(ENV["DOWNLOADS_YAML"])) || []
MOVIE_PATTERN = Regexp.new ENV["MOVIE_PATTERN"]

all = GALLERY.map do |gallery|
  gallery["videos"].map do |video|
    video["link"] if video["title"] =~ MOVIE_PATTERN
  end
end.flatten.compact

done = Dir["#{ENV["DOWNLOAD_DIR"]}/*.url"].map do |file|
  File.read(file).strip
end.uniq

left = all - done

puts <<-EOS
#{left.join("\n")}

All Video Links: #{all.size}
Already Downloaded: #{done.size}
Left: #{left.size}
EOS
