require 'active_record'
require 'multi_spork'

namespace :db do
  namespace :multi_spork do
    def for_each_test_db
      org_test_configuration = ActiveRecord::Base.configurations['test']
      MultiSpork.config.worker_pool.times do |index|
        test_configuration = org_test_configuration.clone
        test_configuration["database"] += (index+1).to_s
        ActiveRecord::Base.configurations['test'] = test_configuration
        yield
      end

      ActiveRecord::Base.configurations['test'] = org_test_configuration

    end

    desc "Clone schema of development db to test dbs to be used by multi_spork worker"
    task :clone => "db:load_config" do
      Rake::Task["db:schema:dump"].invoke
      Rails.env = 'test' # force test environment so db:create take test configuration
      for_each_test_db do
        ["db:create", "db:test:purge", "db:test:load_schema", "db:schema:load"].each do |task_name|
          Rake::Task[task_name].reenable
        end

        Rake::Task["db:create"].invoke
        Rake::Task["db:test:load_schema"].invoke
        Rake::Task["db:seed"].invoke
      end
    end

    desc "Drop all tests db created by clone"
    task :drop do
      Rails.env = 'test' # force to test so dev db is not dropped
      Rake::Task["db:load_config"].invoke

      for_each_test_db do
        Rake::Task["db:drop"].reenable
        Rake::Task["db:drop"].invoke
      end
    end
  end
end
