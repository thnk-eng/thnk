# frozen_string_literal: true

module BubbleSocket
  class Routes < Hanami::Routes
    # Add your routes here. See https://guides.hanamirb.org/routing/overview/ for details.
    #
    root to: 'home.index'
    post '/api/files/upload', to: 'files.upload'
    get '/ws', to: 'websockets.connect'
  end
end
