require 'spec_helper'

describe Middleman::SlateAlgolia::Index do
  before :each do
    stub_request(:any, %r{.*\.algolia(net\.com|\.net)\/*})
      .to_return(body: '{"hits":[]}')
  end

  after :each do
    WebMock.reset!
  end

  describe 'initialize' do
    it 'creates an Algolia Index with the specified name' do
      expect(Algolia::Index).to receive(:new).with('test')

      Middleman::SlateAlgolia::Index.new(
        application_id: '',
        api_key: '',
        name: 'test'
      )
    end

    it 'uses the defined API keys for the Algolia Index' do
      expect(Algolia).to receive(:init).with(application_id: 'id', api_key: 'key').and_call_original

      Middleman::SlateAlgolia::Index.new(
        application_id: 'id',
        api_key: 'key',
        name: ''
      )
    end
  end

  describe 'flush_queue' do
    it 'calls before_index for each record' do
      dbl = double
      index = Middleman::SlateAlgolia::Index.new(
        application_id: '',
        api_key: '',
        dry_run: false,
        before_index: proc do |record|
          # Verify is not a real method. Just a fake thing on a double
          dbl.verify(record)
        end
      )

      index.queue_object(objectID: 1)
      index.queue_object(objectID: 2)

      expect(dbl).to receive(:verify).with(objectID: 1)
      expect(dbl).to receive(:verify).with(objectID: 2)

      index.flush_queue
    end

    it 'replaces records via the before_index hook' do
      index = Middleman::SlateAlgolia::Index.new(
        application_id: '',
        api_key: '',
        dry_run: false,
        before_index: proc do |record|
          { objectID: record[:objectID] * 2 }
        end
      )

      index.queue_object(objectID: 1)
      index.queue_object(objectID: 2)

      expect(index.instance_variable_get('@index')).to receive(:add_objects)
        .with(
          [
            { objectID: 2 },
            { objectID: 4 }
          ]
        )

      index.flush_queue
    end

    it 'creates new records if before_index returns an array' do
      index = Middleman::SlateAlgolia::Index.new(
        application_id: '',
        api_key: '',
        dry_run: false,
        before_index: proc do |record|
          [record, { objectID: record[:objectID] * 4 }]
        end
      )

      index.queue_object(objectID: 1)
      index.queue_object(objectID: 2)

      expect(index.instance_variable_get('@index')).to receive(:add_objects)
        .with(
          [
            { objectID: 1 },
            { objectID: 4 },
            { objectID: 2 },
            { objectID: 8 }
          ]
        )

      index.flush_queue
    end

    it 'reuses the existing record if the before_index hook has no return' do
      index = Middleman::SlateAlgolia::Index.new(
        application_id: '',
        api_key: '',
        dry_run: false,
        before_index: proc do |record|
          # Wassup!
        end
      )

      index.queue_object(objectID: 1)
      index.queue_object(objectID: 2)

      expect(index.instance_variable_get('@index')).to receive(:add_objects)
        .with(
          [
            { objectID: 1 },
            { objectID: 2 }
          ]
        )

      index.flush_queue
    end
  end

  describe 'clean_index' do
    it 'selects records using the :filter_deletes hook' do
      index = Middleman::SlateAlgolia::Index.new(
        application_id: '',
        api_key: '',
        dry_run: false,
        filter_deletes: proc do |record|
          record['objectID'] == "1"
        end
      )

      instance_index = index.instance_variable_get('@index')

      expect(instance_index).to receive(:delete_objects)
        .with(['1'])
      allow(instance_index).to receive(:browse) {
        {
          'hits' => [
            {
              'objectID' => '1'
            },
            {
              'objectID' => '2'
            }
          ]
        }
      }
        
      index.clean_index
    end
  end
end
