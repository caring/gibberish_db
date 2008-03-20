class GibberishController < ApplicationController
  # Probably don't want everyone to do this
  # access_control [:edit, :save] => '(admin | editor | copyeditor)'
  
  # uncomment if you've got ssl pages
  # ssl_allowed :edit, :save if RUN_SSL == true
  
  def edit
    @translation = Gibberish::Translation.find_cached_by_language_and_key(
      Gibberish::Language.find_cached_by_name(params[:lang]),
      params[:id])
    render :text => @translation.value
  end
  
  def save
    @translation = Gibberish::Translation.find_cached_by_language_and_key(
      Gibberish::Language.find_cached_by_name(params[:lang]),
      params[:id])
    if params[:value].blank?
      @translation.destroy
      render :text => "reload the page to see the default value again"
    else
      @translation.value = params[:value]
      @translation.save!
      render :text => @translation.value
    end
  end
end