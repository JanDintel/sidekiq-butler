module Sidekiq
  module Butler
    module Middleware
      module Client
        class Reservation
          attr_reader :table_name

          def call(worker_class, job, queue)
            @options = worker_class.get_sidekiq_options

            validate_sidekiq_options

            @reservation_name         = @butler_options[:reservation][:name]
            @reservation_guest_amount = @butler_options[:reservation][:guests].to_i

            @table_name = "table:#{worker_class.to_s.downcase}:#{@reservation_name}"
            @guest      = job['jid']

            unless guest_is_already_seated?
              if guest_is_unwelcome?
                Sidekiq::Logging.logger.info { "Unable to push the job to Redis. The Sidekiq job for #{worker_class} reached it maximum" }
                return false
              end
            end

            seat_guest_on_table

            yield if block_given?
          end

          def guest_is_already_seated?
            Sidekiq.redis { |r| r.sismember(@table_name, @guest) }
          end

          def guest_is_unwelcome?
            guests_on_table >= @reservation_guest_amount
          end

          def seat_guest_on_table
            Sidekiq.redis { |r| r.sadd(@table_name, @guest) }
          end

          private

          def guests_on_table
            Sidekiq.redis { |r| r.scard(@table_name) }
          end

          def validate_sidekiq_options
            raise ArgumentError, 'the butler option must be defined'                              if @options['butler'].blank?
            raise ArgumentError, 'the reservation option must be defined'                         if @options['butler'][:reservation].blank?
            raise ArgumentError, 'the name argument must be defined in the reservation option'    if @options['butler'][:reservation][:name].blank?
            raise ArgumentError, 'the guests argument must be defined in the reservation option'  if @options['butler'][:reservation][:guests].blank?
            @butler_options = @options['butler']
          end
        end
      end
    end
  end
end
