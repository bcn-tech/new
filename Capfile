require 'rubygems'
require 'bundler/setup'
require 'youthtree-capistrano'

set :application,     "recruitment_platform"
set :repository_name, "recruitment_platform"

set :bundle_without, [:development, :test, :test_mac]

set :git_enable_submodules, true

# Use git-flow based branches for deployment.
set :branch do
  stage == "production" ? "master" : "develop"
end

set :aai_index_shared, 'index'
set :aai_index_latest, 'index'

set :deploy_via, :remote_cache

namespace :acts_as_indexed do

  desc "Creates the index dir in the shared path"
  task :setup do
    run "mkdir -p '#{shared_path}/#{aai_index_shared}'"
  end

  desc "Symlinks the aai dir into place"
  task :symlink do
    symlink_config aai_index_shared, aai_index_latest
  end

  after 'deploy:setup',       'acts_as_indexed:setup'
  after 'deploy:update_code', 'acts_as_indexed:symlink'

end