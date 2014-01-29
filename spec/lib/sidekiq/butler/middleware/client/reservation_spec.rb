require 'spec_helper'

describe Sidekiq::Butler::Middleware::Client::Reservation do

  before { Sidekiq.redis(&:flushdb) }

  let(:worker_class)    { Sidekiq::Butler::Testing::WorkerWithReservation }
  let(:queue)           { 'default' }
  let(:job) do
    Hash.try_convert({"retry"=>true, "queue"=>"default", "butler"=>{:reservation=>{:name=>"mies", :guests=>2}},
      "class"=>"Sidekiq::Butler::Testing::WorkerWithReservation", "args"=>[], "jid"=>"055e0a2fe0abdb0f67e76611", "enqueued_at"=>1390945801.609961})
  end

  describe '#sidekiq_options' do
    describe 'presence of butler reservation options' do
      before { Sidekiq::Butler::Testing::Worker.sidekiq_options Sidekiq.default_worker_options }

      it '#butler' do
        Sidekiq::Butler::Testing::Worker.sidekiq_options butler: {}
        expect{ Sidekiq::Butler::Testing::Worker.perform_async }.to raise_error ArgumentError, 'the butler option must be defined'
      end

      it '#reservation' do
        Sidekiq::Butler::Testing::Worker.sidekiq_options butler: { reservation: {} }
        expect{ Sidekiq::Butler::Testing::Worker.perform_async }.to raise_error ArgumentError, 'the reservation option must be defined'
      end

      it '#name' do
        Sidekiq::Butler::Testing::Worker.sidekiq_options butler: { reservation: { foo: '' } }
        expect{ Sidekiq::Butler::Testing::Worker.perform_async }.to raise_error ArgumentError, 'the name argument must be defined in the reservation option'
      end

      it '#guests' do
        Sidekiq::Butler::Testing::Worker.sidekiq_options butler: { reservation: { name: 'foo' } }
        expect{ Sidekiq::Butler::Testing::Worker.perform_async }.to raise_error ArgumentError, 'the guests argument must be defined in the reservation option'
      end
    end
  end

  describe '#call' do
    describe 'middleware is allowed to yield' do
      it 'pushes the job to redis' do
        expect(worker_class.perform_async).not_to be_nil
      end

      it 'sidekiq job is already reserved, thus pushes to redis' do
        described_class.any_instance.stub(:guest_is_already_seated?) { true }

        expect(worker_class.perform_async).not_to be_nil
      end
    end

    describe 'middleware is not allowed to yield' do
      it 'sidekiq job maximum is reached, thus does NOT push to redis' do
        described_class.any_instance.stub(:guest_is_already_seated?)        { false }
        described_class.any_instance.stub(:guest_is_unwelcome?)  { true }

        expect(worker_class.perform_async).to be_nil
      end
    end
  end

  describe '#table_name' do
    specify do
      subject.call(worker_class, job, queue)
      expect(subject.table_name).to eql 'table:sidekiq::butler::testing::workerwithreservation:mies'
    end
  end

  describe '#guest_is_already_seated?' do
    before { described_class.any_instance.stub(:seat_guest_on_table) }

    context 'sidekiq job is already reserved' do
      let(:table_name)  { 'table:sidekiq::butler::testing::workerwithreservation:mies' }
      let(:guest)       { job['jid'] }

      specify do
        Sidekiq.redis { |r| r.sadd(table_name, guest) }

        subject.call(worker_class, job, queue)
        expect(subject.guest_is_already_seated?).to be_true
      end
    end

    context 'sidekiq job is NOT reserved' do
      specify do
        subject.call(worker_class, job, queue)
        expect(subject.guest_is_already_seated?).to be_false
      end
    end
  end

  describe '#guest_is_unwelcome?' do
    let(:table_name)  { 'table:sidekiq::butler::testing::workerwithreservation:mies' }
    let(:guest)       { job['jid'] }

    context 'maximum jobs for sidekiq worker reached' do
      specify do
        Sidekiq.redis { |r| r.sadd(table_name, 'foo') }
        Sidekiq.redis { |r| r.sadd(table_name, 'bar') }

        subject.call(worker_class, job, queue)
        expect(subject.guest_is_unwelcome?).to be_true
      end
    end

    context 'logs to the sidekiq logger if maximum jobs is reached' do
      specify do
        described_class.any_instance.stub(:guest_is_unwelcome?) { true }

        expect(Sidekiq::Logging.logger).to receive(:info)
        subject.call(worker_class, job, queue)
      end
    end

    context 'maximum jobs for sidekiq worker NOT reached' do
      specify do
        subject.call(worker_class, job, queue)
        expect(subject.guest_is_unwelcome?).to be_false
      end
    end
  end

  describe '#seat_guest_on_table' do
    let(:table_name)  { 'table:sidekiq::butler::testing::workerwithreservation:mies' }

    it 'adds the sidekiq job to the reserved set' do
      subject.instance_variable_set('@table_name', table_name)
      expect{ subject.seat_guest_on_table }.to change{ Sidekiq.redis { |r| r.scard(table_name) } }.by 1
    end
  end
end
