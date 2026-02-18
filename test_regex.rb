# Test the regex patterns
titles = [
  "3-Cushion French League 2025/2026 - Glenn HOFMAN vs Marco ZANETTI",
  "Kozoom League 2025/2026 - Round 13 - Dave CHRISTIANI vs Nikos POLYCHRONOPOULOS",
  "Kozoom League 2025/2026 - Round 13 - Eddy MERCKX vs Dick JASPERS"
]

titles.each do |title|
  puts "\n" + "=" * 80
  puts "Title: #{title}"
  
  # Test season pattern
  if title.match?(/\b(20\d{2})\/(20\d{2})\b/)
    match = title.match(/\b(20\d{2})\/(20\d{2})\b/)
    puts "  ✅ Season matched: #{match[1]}/#{match[2]}"
    puts "  Year would be: #{match[2].to_i}"
    puts "  Season would be: #{match[1]}/#{match[2]}"
  else
    puts "  ❌ Season pattern did NOT match"
  end
  
  # Test single year pattern
  if title.match?(/\b(20\d{2})\b/)
    match = title.match(/\b(20\d{2})\b/)
    puts "  ✅ Single year matched: #{match[1]}"
  else
    puts "  ❌ Single year pattern did NOT match"
  end
end
