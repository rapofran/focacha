require_relative 'models/channel'
require_relative 'models/message'
require_relative 'models/user'

module Focacha
  class Application < Sinatra::Base
    configure do
      # method override
      use Rack::MethodOverride

      # mongoid
      Mongoid.load! 'config/mongoid.yml', environment

      # omniauth
      use OmniAuth::Builder do
        provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_SECRET']
        provider :twitter, ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET']
      end

      # sessions
      enable :sessions
      set :session_secret, 'focacha secret'

      # slim
      set :slim, layout: :'layouts/focacha'

      # static
      set :static, true

      # twitter
      Twitter.configure do |config|
        config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
      end
    end

    helpers do
      def current_user
        @user ||= User.find_by(uid: session[:uid]) if session[:uid]
      end

      def html_pipeline
        @html_pipeline ||= HTML::Pipeline.new [
          HTML::Pipeline::MarkdownFilter,
          HTML::Pipeline::SanitizationFilter,
          HTML::Pipeline::CamoFilter,
          HTML::Pipeline::ImageMaxWidthFilter,
          HTML::Pipeline::HttpsFilter,
          HTML::Pipeline::MentionFilter,
          HTML::Pipeline::EmojiFilter,
          HTML::Pipeline::SyntaxHighlightFilter
        ], { asset_root: '/images/' }
      end
    end

    before do
      pass if request.path_info =~ /\/auth\//

      unless current_user
        halt 401, slim(:'auth/sign_in', layout: :'layouts/unauthorized')
      end
    end

    get '/' do
      slim :index, locals: { channels: Channel.all, channel: Channel.new }
    end

    get '/auth/:provider/callback' do
      auth = request.env['omniauth.auth']
      user = User.find_by(provider: auth['provider'], uid: auth['uid']) || User.create_with_omniauth(auth)
      session[:uid] = user.uid
      redirect '/'
    end

    get '/auth/failure' do
      slim :'auth/failure', layout: :'layouts/unauthorized'
    end

    delete '/auth/destroy' do
      session[:uid] = nil
      redirect '/'
    end

    post '/channels' do
      channel = Channel.new params[:channel]
      channel.user = current_user

      if channel.valid?
        channel.save
        redirect '/', 301
      else
        slim :index, locals: { channels: Channel.all, channel: Channel.new }
      end
    end

    get '/channels/:id' do
      channel = Channel.find_by(id: params[:id])
      slim :show, locals: { channel: channel }
    end

    post '/channels/:id/messages' do
      channel = Channel.find_by(id: params[:id])
      message = channel.messages.new params[:message]
      message.user = current_user

      if message.valid?
        message.save
        redirect "/channels/#{channel.id}", 301
      else
        slim :show, locals: { channel: channel }
      end
    end
  end
end
