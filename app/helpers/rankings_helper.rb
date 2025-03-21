module RankingsHelper
  def format_gd(value)
    return '-' if value.nil?
    format("%.3f", value)
  end

  def format_btg(value)
    return '-' if value.nil?
    format("%.3f", value)
  end
end 