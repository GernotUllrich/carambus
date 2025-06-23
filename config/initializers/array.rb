class Array
  def extract(val)
    include?(val) ? [val] : []
  end
end
