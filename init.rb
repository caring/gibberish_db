require 'gibberish_db'
require 'gibberish_db/gibberish_helper'

ActionController::Base.send :after_filter do
  Gibberish::Localize::reset_translations
end