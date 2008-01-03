module Gibberish
  
  class Language < ActiveRecord::Base
    has_many :translations
  end
  
  class Translation < ActiveRecord::Base
    belongs_to :language
    acts_as_cached
    after_save :invalidate_value_cache
    validates_length_of :key, :within => 1..100
    def self.find_cached_value_by_language_and_key(lang,key)
      get_cache("find_value_by_language_id_and_key:#{lang.id}:#{MD5.md5(key.to_s)}") do
        Translation.find_by_language_id_and_key(lang.id,key.to_s).value
      end
    end
    def invalidate_value_cache
      clear_cache("find_value_by_language_id_and_key:#{self.language_id}:#{MD5.md5(self.key)}")
    end
  end
  
  # this is an adapter that exposes a Hash access method
  # but calls to the model for the correct language.
  class Translator
    def initialize(language)
      @language = language
    end
    def translate(key)
      Translation.find_cached_value_by_language_and_key(@language,key)
    end
    alias_method :[], :translate
  end
  
  module Localize    
    def load_languages_with_db!
      Language.find(:all).each do |lang|
        @@languages[lang.name.to_sym] = Translator.new(lang)
      end
    end
    alias_method_chain :load_languages!, :db
  end
end