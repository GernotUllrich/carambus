module DarkModeHelper
  def set_dark_mode(enabled)
    cookies[:dark_mode] = enabled ? '1' : '0'
  end

  def dark_mode?
    case cookies[:dark_mode]
    when '1' then true
    when '0' then false
    else nil
    end
  end

  def set_system_theme
    cookies.delete(:dark_mode)
  end
end 