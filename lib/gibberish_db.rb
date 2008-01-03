module Gibberish
  
  class Language < ActiveRecord::Base
    has_many :translations
    acts_as_cached
    after_save :invalidate_cache
    def self.find_cached_by_name(name)
      get_cache("find_by_name:#{name}") do
        find(:first, :conditions => {:name => name.to_s})
      end
    end
    def invalidate_cache
      clear_cache "find_by_name:#{name}"
    end
  end
  
  class Translation < ActiveRecord::Base
    belongs_to :language
    acts_as_cached
    after_save :invalidate_cache
    after_destroy :invalidate_cache
    validates_length_of :key, :within => 1..100
    attr_accessor :arguments
    def self.find_cached_by_language_and_key(lang,key)
      get_cache("find_by_language_id_and_key:#{lang.id}:#{MD5.md5(key.to_s)}") do
        Translation.find_by_language_id_and_key(lang.id,key.to_s)
      end
    end
    def invalidate_cache
      clear_cache("find_by_language_id_and_key:#{self.language_id}:#{MD5.md5(self.key.to_s)}")
    end
    
    def method_missing(name, *args, &block)
      return super if @attributes.include?(name.to_s)
      if self.value.respond_to?(name)
        if block_given?
          self.interpolated_value.send(name, *args, &block)
        else
          self.interpolated_value.send(name, *args)
        end
      else
        super
      end
    end
    
    def interpolated_value
      args = (arguments || []).dup 
      self.value.gsub(/\{\w+\}/) { args.shift }
    end
    
    def to_s
      interpolated_value
    end
  end
  
  # this is an adapter that exposes a Hash access method
  # but calls to the model for the correct language.
  class Translator
    def initialize(language)
      @language = language
    end
    def translate(key)
      Translation.find_cached_by_language_and_key(@language,key)
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
    def create_translation!(string, key)
      Translation.create!(:value => string, :key => key.to_s, :language_id => Language.find_cached_by_name(current_language).id)
    end
    def translate_with_db(string, key, *args)
      return if reserved_keys.include? key
      target = translations[key] || create_translation!(string,key)
      interpolate_string(target.dup, *args.dup)
    end
    alias_method_chain :translate, :db
    private
      def interpolate_string(string, *args)
        if string.is_a? Translation
          string.arguments = args
          string
        else
          string.gsub(/\{\w+\}/) { args.shift }
        end
      end
  end
end