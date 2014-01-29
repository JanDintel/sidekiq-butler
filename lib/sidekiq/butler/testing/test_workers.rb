module Sidekiq
  module Butler
    module Testing
      class Worker
        include Sidekiq::Worker

        def perform
        end
      end
      class WorkerWithReservation
        include Sidekiq::Worker

        sidekiq_options butler: { reservation: { name: 'mies', guests: 2 } }

        def perform
        end
      end
    end
  end
end
