require 'gibberish_db'
require 'gibberish_db/gibberish_helper'

class ActionController::Base

  protected

  def reset_gibberish_translations
    Gibberish::Localize::reset_translations
  end
end

ActionController::Base.send :after_filter, :reset_gibberish_translations