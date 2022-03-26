#!/usr/bin/env ruby

Dir.glob("/Users/gullrich/PycharmProjects/normalize_graph/diagrams/d???.jpg") do |rb_filename|
  f = File.basename(rb_filename)
  m = f.match(/d(\d\d\d).jpg/)
  if m[1]
    FileUtils.mv(rb_filename, "/Users/gullrich/PycharmProjects/normalize_graph/diagrams/d#{m[1]}r.jpg")
  end
end
