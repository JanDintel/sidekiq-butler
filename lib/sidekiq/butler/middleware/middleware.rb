require 'sidekiq/butler/middleware/client/reservation'
require 'sidekiq/butler/middleware/server/reservation'

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Butler::Middleware::Client::Reservation
  end
end

Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Butler::Middleware::Client::Reservation
  end

  config.server_middleware do |chain|
    chain.add Sidekiq::Butler::Middleware::Server::Reservation
  end
end
