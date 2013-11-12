# encoding: UTF-8
require 'json'
require 'sinatra'


configure do
  # Define greetings for different times of the day in different languages.
  set :greetings, {
    'english'    => ['Good morning', 'Hello', 'Good evening'], 
    'french'     => ['Bonjour', 'Bonjour', 'Bonsoir'], 
    'german'     => ['Guten morgen', 'Hallo', 'Guten abend'], 
    'spanish'    => ['Buenos días', 'Hola', 'Buenas noches'], 
    'portuguese' => ['Bom dia', 'Olá', 'Boa noite'], 
    'italian'    => ['Buongiorno', 'Ciao', 'Buonasera'], 
    'swedish'     => ['God morgon', 'Hallå', 'God kväll']
  }
end


get '/' do
  return 'A Little Printer publication.'
end


# Called to generate the sample shown on BERG Cloud Remote.
#
# == Parameters:
#   None.
#
# == Returns:
# HTML/CSS edition.
#
get '/sample/' do
  @greeting = "#{settings.greetings['english'][0]}, Little Printer"
  erb :edition
end


# Prepares and returns an edition of the publication.
#
# == Parameters:
# lang
#   The language for the greeting.
#   The subscriber will have picked this from the values defined in meta.json.
# name
#   The name of the person to greet.
#   The subscriber will have entered their name at the subscribe stage.
# local_delivery_time
#   The local time where the subscribed bot is.
#
# == Returns:
# HTML/CSS edition with ETag.
# 
get '/edition/' do
  if params[:lang].nil? || ! settings.greetings.include?(params[:lang])
    return 400, 'Error: Invalid or missing lang parameter'
  end
  if params[:name].nil? || params[:name] == ''
    return 400, 'Error: No name provided'
  end
  
  # local_delivery_time is like '2013-10-16T23:20:30-08:00'.
  begin
    date = DateTime.parse(params[:local_delivery_time])
  rescue
    return 400, 'Error: Invalid or missing local_delivery_time'
  end

  # The publication is only delivered on Mondays, so if it's not a Monday in
  # the subscriber's timezone, we return nothing but a 204 status.
  if ! date.monday?
    return 204
  end
  
  # Extract configuration provided by user through BERG Cloud.
  # These options are defined in meta.json.
  language = params[:lang]
  name = params[:name]
  
  # Pick a time of day appropriate greeting
  i = 1
  case date.hour
  when 4..11
    i = 0
  when 12..17
    i = 1
  when 18..24
  when 0..3
    i = 2
  end

  # Base the ETag on the unique content: language, name and date.
  # This means the user will not get the same content twice.
  # But, if they reset their subscription (with, say, a different language)
  # they will get new content.
  etag Digest::MD5.hexdigest(language+name+date.strftime('%d%m%Y'))
  
  @greeting = "#{settings.greetings[language][i]}, #{name}"
  
  erb :edition
end


# == Parameters:
# :config
#   params[:config] contains a JSON array of responses to the options defined
#   by the fields object in meta.json. In this case, something like:
#   params[:config] = ["name":"SomeName", "lang":"SomeLanguage"]
#
# == Returns:
# A JSON response object.
# If the parameters passed in are valid: {"valid":true}
# If the parameters passed in are not valid: {"valid":false,"errors":["No name was provided"], ["The language you chose does not exist"]}
#
post '/validate_config/' do
  if params[:config].nil?
    return 400, 'There is no config to validate.'
  end

  # Preparing what will be returned:
  response = {
    :errors => [],
    :valid => true
  }

  # Extract the config from the POST data and parse its JSON contents.
  # user_settings will be something like: {"name":"Alice", "lang":"english"}.
  user_settings = JSON.parse(params[:config])
  p user_settings

  # If the user did choose a language:
  if user_settings[:lang].nil? || user_settings[:lang] == ''
    response[:valid] = false
    response[:errors] << 'Please choose a language from the menu.'
  end
  
  # If the user did not fill in the name option:
  if user_settings[:name].nil? || user_settings[:name] == ''
    response[:valid] = false
    response[:errors] << 'Please enter your name into the name box.'
  end
  
  unless settings.greetings.include?(user_settings[:lang].downcase)
    # Given that the select field is populated from a list of languages
    # we defined this should never happen. Just in case.
    response[:valid] = false
    response[:errors] << "We couldn't find the language you selected (#{user_settings[:lang]}). Please choose another."
  end
  
  content_type :json
  response.to_json
end

