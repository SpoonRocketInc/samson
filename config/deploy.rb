require 'capistrano/puma'
require 'capistrano/puma/workers' #if you want to control the workers (in cluster mode)
require 'capistrano/puma/jungle'  #if you need the jungle tasks
require 'capistrano/puma/monit'   #if you need the monit tasks
require 'capistrano/puma/nginx'   #if you want to upload a nginx site template

set :application, 'samson'
set :repo_url, 'git@github.com:SpoonRocketInc/samson.git'

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
set :deploy_to, "/home/apps/samson"

set :branch, "production"
set :scm, :git

set :format, :pretty
# set :log_level, :debug
# set :pty, true

set :linked_files, %w{config/database.yml .env}
set :linked_dirs,  %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/assets cached_repos}

set :bundle_without, %w{development test postgres sqlite}.join(' ')

set :puma_rackup, -> { File.join(current_path, 'config.ru') }
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"    #accept array for multi-bind
set :puma_conf, "#{shared_path}/puma.rb"
set :puma_access_log, "#{shared_path}/log/puma_error.log"
set :puma_error_log, "#{shared_path}/log/puma_access.log"
set :puma_role, :app
set :puma_env, fetch(:rack_env, fetch(:rails_env, 'production'))
set :puma_threads, [0, 16]
set :puma_workers, 0
set :puma_worker_timeout, nil
set :puma_init_active_record, false
set :puma_preload_app, true

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
# set :keep_releases, 5

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  after :restart,   'puma:restart'
  after :finishing, 'deploy:cleanup'

end
