module LanguageHelper
  LANGUAGES = {
    de: "Deutsch",
    en: "English"
  }

  def language_options
    LANGUAGES.slice(*I18n.available_locales).invert.to_a
  end

  def language_flag(locale)
    case locale.to_s
    when 'de'
      'flags/de.svg'
    when 'en'
      'flags/en.svg'
    else
      'flags/unknown.svg'
    end
  end

  def language_name(locale)
    I18n.t("locales.#{locale}", default: locale.to_s.upcase)
  end
end
