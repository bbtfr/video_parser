require 'yaml'

ENV["DOWNLOADS"] ||= "downloads.yml"
ENV["DOWNLOAD_DIR"] ||= "downloads"

GALLERY = YAML.load(File.read(ENV["DOWNLOADS"])) || []

all = GALLERY.map do |gallery|
  gallery["videos"].map do |video|
    video["link"]
  end
end.flatten

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
