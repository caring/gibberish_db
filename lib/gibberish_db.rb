module Gibberish
  
  class Language < ActiveRecord::Base
    has_many :translations
    acts_as_cached
    after_save :invalidate_cache

    # I'm just going to hold onto these really strongly
    # This will be a bug if we change the actual languages a lot
    @@languages_by_name = {}
    @@languages_by_id = {}

    def self.find_cached_by_name(name)
      @@languages_by_name[name] ||= get_cache("find_by_name:#{name}") do
        find(:first, :conditions => {:name => name.to_s})
      end
    end

    def self.find_cached_by_id(id)
      @@languages_by_id[id] ||= get_cache id
    end

    def invalidate_cache
      clear_cache "find_by_name:#{name}"
      @@languages_by_name = {}
      @@languages_by_id = {}
    end

  end
  
  class Translation < ActiveRecord::Base
    belongs_to :language
    acts_as_cached
    after_save :invalidate_cache
    after_destroy :invalidate_cache
    validates_length_of :key, :within => 1..100
    validates_uniqueness_of :key, :scope => :language_id
    validates_inclusion_of :format, :in => ['block','inline'], :on => :create

    attr_accessor :arguments

    def self.full_cached
      get_cache("everything") do
        returning({}) do |rv|
          Translation.find(:all, :include => :language).group_by{|l| [l.language_id, l.key]}.each do |p|
            rv[p.first] = p.last.last
          end
        end
      end
    end

    def self.find_cached_by_language_and_key(lang, key)
      full_cached[[lang.is_a?(Language) ? lang.id : lang, key]].first
    end

    def invalidate_cache
      self.class.clear_cache "everything"
      Gibberish::Localize::reset_translations
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
      if args.last.is_a? Hash
        interpolate_with_hash(self.value, args.last)
      else
        interpolate_with_strings(self.value, args)
      end
    end

    def interpolate_with_hash(string, hash)
      hash.inject(string) do |target, (search, replace)|
        if search and replace
          target.gsub("{#{search}}", replace)
        else
          RAILS_DEFAULT_LOGGER.warn "Problem interpolating #{string} with #{hash.inspect}"
          target
        end
      end 
    end

    def interpolate_with_strings(string, strings)
      string.gsub(/\{\w+\}/) { strings.shift }
    end
        
    def to_str
      interpolated_value
    end
    
    def to_s
      interpolated_value
    end
    
    def to_html
      if Translation.suppress_html_wrapper?
        interpolated_value
      else
        tagname = (self.format == "block") ? "div" : "span"
        %Q{<#{tagname} class="translated key_#{key}" lang="#{language.name}">#{interpolated_value}</#{tagname}>}
      end
    end
                    
    # Execute a block of code while suppressing the HTML wrapping that would
    # otherwise take place when invoking .to_html
    def self.suppressing_html_wrapping(&block)
      old_val = @suppress_html
      @suppress_html = true
      begin 
        yield
      ensure
        @suppress_html = old_val
      end
    end
    
    def self.suppress_html_wrapper?
      @suppress_html
    end    
  end
  
  # this is an adapter that exposes a Hash access method
  # but calls to the model for the correct language.
  class Translator

    def initialize(language)
      @language = language
    end

    def translate(key)
      all_translations[[@language.is_a?(Language) ? @language.id : @language, key.to_s]]
    end
    alias_method :[], :translate

    def all_translations
      @cached ||= Translation.full_cached
    end

    def reset_translations
      @cached = nil
    end
  end
  
  module Localize
    def load_languages_with_db!
      Language.find(:all).each do |lang|
        @@languages[lang.name.to_sym] = Translator.new(lang)
      end
    end
    alias_method_chain :load_languages!, :db
    def create_translation(string, key, *args)
      format = args.first.delete(:format) if args.first.is_a?(Hash)
      format ||= :inline
      returning Translation.create(:value => string,
                                  :key => key.to_s,
                                  :language_id => Language.find_cached_by_name(current_language).id,
                                  :format => format.to_s) do |translation|
        RAILS_DEFAULT_LOGGER.warn "Failed to create translation: #{translation.errors.full_messages}" unless translation.errors.empty?
      end
    end

    def translate_with_db(string, key, *args)
      return if reserved_keys.include? key
      target = translations[key] || create_translation(string,key,*args)
      arguments = extract_arguments(args)
      interpolate_string(target.dup, *arguments.dup)
    end
    alias_method_chain :translate, :db

    def self.reset_translations
      @@languages.each { |k,v| v.reset_translations }
    end

    private

      def extract_arguments(args)
         if (options = args.first).is_a?(Hash)
           [:format].each {|opt| options.delete(opt)}
         end
         return args
      end

      def interpolate_string_with_db(string, *args)
        if string.is_a? Translation
          string.arguments = args
          string
        else
          interpolate_string_without_db(string, *args)
        end
      end
      alias_method_chain :interpolate_string, :db
  end

end

class ActionMailer::Base
  class << self
    # We want .to_html to be active when invoking action mailer through the
    # create_XXX functions so that we can edit them in the menagerie. But,
    # we want it to be inactive through the deliver_XXX functions so that end
    # users don't see the extra markup. We make that happen here.
    def method_missing_with_html_suppression(method_symbol, *parameters)
      case method_symbol.id2name
      when /^deliver_([_a-z]\w*)/
        # No HTML for mails that are being delivered
        Gibberish::Translation.suppressing_html_wrapping do
          method_missing_without_html_suppression(method_symbol, *parameters)
        end
      else
        # Pass through for the others
        method_missing_without_html_suppression(method_symbol, *parameters)
      end
    end
    alias_method_chain :method_missing, :html_suppression
  end
end
