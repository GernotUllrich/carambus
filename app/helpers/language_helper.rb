module LanguageHelper
  LANGUAGES = {
    de: "Deutsch",
    en: "English"
  }

  def language_options
    LANGUAGES.slice(*I18n.available_locales).invert.to_a
  end
end
