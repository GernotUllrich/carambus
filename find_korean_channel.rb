require 'cgi'
require 'uri'

url = "https://www.youtube.com/@%EC%8A%A4%ED%8F%AC%EB%86%80%EC%9D%B4%ED%84%B0-n9x"

# Decode URL
decoded = CGI.unescape(url)
puts "Original URL: #{url}"
puts "Decoded URL: #{decoded}"

# Extract handle
handle = decoded.split('@').last
puts "Handle: #{handle}"
