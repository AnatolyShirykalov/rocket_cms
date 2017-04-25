rails_spec = (Gem.loaded_specs["railties"] || Gem.loaded_specs["rails"])
version = rails_spec.version.to_s

mongoid = options[:skip_active_record]
yarn = !options[:skip_yarn]
spring = !options[:skip_spring]

if Gem::Version.new(version) < Gem::Version.new('5.0.0')
  puts "You are using an old version of Rails (#{version})"
  puts "Please update"
  puts "Stopping"
  exit 1
end

git :init

remove_file 'Gemfile'
create_file 'Gemfile' do <<-TEXT
source 'https://rubygems.org'

gem 'rails', '5.1.0.rc1'
#{if mongoid then "gem 'mongoid', '~> 6.1.0'" else "gem 'pg'" end}

gem 'sass'

#{if mongoid then "gem 'rocket_cms_mongoid'" else "gem 'rocket_cms_activerecord'" end}
gem 'rails_admin', github: 'crowdtask/rails_admin'

gem 'slim', github: 'slim-template/slim'
gem 'haml', github: 'haml/haml'
gem 'sass-rails'
gem 'webpack-rails'

gem 'devise'
gem 'devise-i18n'
gem 'cancancan'

gem 'cloner'
gem 'puma'

gem 'x-real-ip'
gem 'sentry-raven'

gem 'uglifier'

# windows
gem 'tzinfo-data'
gem 'wdm', '>= 0.1.0' if Gem.win_platform?

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry-rails'
  gem 'listen'
  #{"gem 'spring'" if spring}

  gem 'capistrano', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano3-puma', require: false
  gem 'capistrano-rails', require: false

  gem 'hipchat'
end

group :test do
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'email_spec'
  #{if mongoid then "gem 'mongoid-rspec'" else "" end}
  gem 'ffaker'
  gem 'factory_girl_rails'
end

TEXT
end

remove_file '.gitignore'
create_file '.gitignore' do <<-TEXT
# See https://help.github.com/articles/ignoring-files for more about ignoring files.
#
# If you find yourself ignoring temporary files generated by your text editor
# or operating system, you probably want to add a global ignore instead:
#   git config --global core.excludesfile '~/.gitignore_global'

/.bundle
/log/*.log
/tmp
/public/system
/public/ckeditor_assets
/public/assets
/node_modules
/public/webpack
#{if mongoid then '/config/mongoid.yml' else '/config/database.yml' end}
/config/secrets.yml
TEXT
end

create_file 'extra/.gitkeep', ''

remove_file 'app/controllers/application_controller.rb'
create_file 'app/controllers/application_controller.rb' do <<-TEXT
class ApplicationController < ActionController::Base
  include RocketCMS::Controller
end
TEXT
end

create_file 'config/navigation.rb' do <<-TEXT
# empty file to please simple_navigation, we are not using it
# See https://github.com/rs-pro/rocket_cms/blob/master/app/controllers/concerns/rs_menu.rb
TEXT
end

remove_file 'README.md'
create_file 'README.md', "## #{app_name}
Project generated by RocketCMS

ORM: #{if mongoid then 'Mongoid' else 'ActiveRecord' end}

To run (windows):
```
.\node_modules\.bin\webpack-dev-server.cmd --config config\webpack.config.js --hot --inline
bundle exec rails s webrick
```


To run (nix/mac):
```
./node_modules/.bin/webpack-dev-server --config config/webpack.config.js --hot --inline
puma
```
"

#create_file '.ruby-version', "2.4.0\n"
#create_file '.ruby-gemset', "#{app_name}\n"

run 'bundle install --without production'

if mongoid
create_file 'config/mongoid.yml' do <<-TEXT
development:
  clients:
    default:
      database: #{app_name.downcase}_development
      hosts:
          - localhost:27017
  options:
    belongs_to_required_by_default: false

test:
  clients:
    default:
      database: #{app_name.downcase}_test
      hosts:
          - localhost:27017
  options:
    belongs_to_required_by_default: false

TEXT
end
else
remove_file 'config/database.yml'
create_file 'config/database.yml' do <<-TEXT
development:
  adapter: postgresql
  encoding: unicode
  database: #{app_name.downcase}_development
  pool: 5
  host: 'localhost'
  username: #{app_name.downcase}
  password: #{app_name.downcase}
  template: template0
TEXT
end
say "Please create a PostgreSQL user #{app_name.downcase} with password #{app_name.downcase} and a database #{app_name.downcase}_development owned by him for development NOW.", :red
ask("Press <enter> when done.")
end

unless mongoid
  generate 'simple_captcha'
end

generate "simple_form:install"
generate "devise:install"
generate "devise", "User"
remove_file "config/locales/devise.en.yml"
remove_file "config/locales/en.yml"

gsub_file 'app/models/user.rb', '# :confirmable, :lockable, :timeoutable and :omniauthable', '# :confirmable, :registerable, :timeoutable and :omniauthable'
gsub_file 'app/models/user.rb', ':registerable,', ' :lockable,'
if mongoid
gsub_file 'app/models/user.rb', '# field :failed_attempts', 'field :failed_attempts'
gsub_file 'app/models/user.rb', '# field :unlock_token', 'field :unlock_token'
gsub_file 'app/models/user.rb', '# field :locked_at', 'field :locked_at'
end

if mongoid
  generate "ckeditor:install", "--orm=mongoid", "--backend=paperclip"
else
  generate "ckeditor:install", "--orm-active_record", "--backend=paperclip"
end

unless mongoid
  generate "rocket_cms:migration"
  generate "rails_admin_settings:migration"
end

generate "rocket_cms:admin"
generate "rocket_cms:ability"
generate "rocket_cms:layout"
generate "rocket_cms:webpack"

unless mongoid
  rake "db:migrate"
end

generate "rspec:install"

remove_file 'config/routes.rb'
create_file 'config/routes.rb' do <<-TEXT
Rails.application.routes.draw do
  devise_for :users
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  mount Ckeditor::Engine => '/ckeditor'

  #get 'contacts' => 'contacts#new', as: :contacts
  #post 'contacts' => 'contacts#create', as: :create_contacts
  #get 'contacts/sent' => 'contacts#sent', as: :contacts_sent

  #get 'search' => 'search#index', as: :search

  #resources :news, only: [:index, :show]

  root to: 'home#index'

  get '*slug' => 'pages#show'
  resources :pages, only: [:show]
end
TEXT
end

create_file 'config/locales/ru.yml' do <<-TEXT
ru:
  attributes:
    is_default: По умолчанию
  mongoid:
    models:
      item: Товар
    attributes:
      item:
        price: Цена
TEXT
end

remove_file 'db/seeds.rb'

require 'securerandom'
admin_pw = SecureRandom.urlsafe_base64(6)
create_file 'db/seeds.rb' do <<-TEXT
admin_pw = "#{admin_pw}"
User.destroy_all
User.create!(email: 'admin@#{app_name.dasherize.downcase}.ru', password: admin_pw, password_confirmation: admin_pw)

Page.destroy_all
Menu.destroy_all
h = Menu.create(name: 'Главное', text_slug: 'main').id
p = Page.create!(name: 'Проекты', content: 'проекты', fullpath: '/projects', menu_ids: [h])
Page.create!(name: 'Прайс лист', fullpath: '/price', menu_ids: [h])
Page.create!(name: 'Галерея', fullpath: '/galleries', menu_ids: [h])
c = Page.create!(name: 'О компании', fullpath: '/company', menu_ids: [h], content: 'О Компании')
Page.create!(name: 'Новости', fullpath: '/news', menu_ids: [h])
Page.create!(name: 'Контакты', fullpath: '/contacts', menu_ids: [h], content: 'Текст стр контакты')

TEXT
end

create_file 'config/initializers/rack.rb' do <<-TEXT
Rack::Utils.multipart_part_limit = 0

if Rails.env.development?
  module Rack
    class CommonLogger
      alias_method :log_without_assets, :log
      #{'ASSETS_PREFIX = "/#{Rails.application.config.assets.prefix[/\A\/?(.*?)\/?\z/, 1]}/"'}
      def log(env, status, header, began_at)
        unless env['REQUEST_PATH'].start_with?(ASSETS_PREFIX) || env['REQUEST_PATH'].start_with?('/uploads')  || env['REQUEST_PATH'].start_with?('/system')
          log_without_assets(env, status, header, began_at)
        end
      end
    end
  end
end
TEXT
end

create_file 'app/assets/stylesheets/rails_admin/custom/theming.css.sass' do <<-TEXT
.navbar-brand
  margin-left: 0 !important

.input-small
  width: 150px

.container-fluid
  input[type=text]
    width: 380px !important
  input.ra-filtering-select-input[type=text]
    width: 180px !important
  input.hasDatepicker
    width: 180px !important

.sidebar-nav
  a
    padding: 6px 10px !important
  .dropdown-header
    padding: 10px 0px 3px 9px

.label-important
  background-color: #d9534f
.alert-notice
  color: #5bc0de

.page-header
  display: none
.breadcrumb
  margin-top: 20px

.control-group
  clear: both

.container-fluid
  padding-left: 0
  > .row
    margin: 0

.last.links
  a
    display: inline-block
    padding: 3px
    font-size: 20px

.remove_nested_fields
  opacity: 1 !important

.model-dialog
  width: 800px !important

.content > .alert
  margin-top: 20px

.badge-important
  background: red
.badge-success
  background: green

.sidebar-nav i
  margin-right: 5px
TEXT
end

remove_file 'public/robots.txt'
create_file 'public/robots.txt' do <<-TEXT
User-Agent: *
Disallow: /
TEXT
end

port = rand(100..999) * 10

remove_file 'config/puma.rb'
create_file 'config/puma.rb' do <<-TEXT
# Min and Max threads per worker
threads 1, 3

current_dir = File.expand_path("../..", __FILE__)
base_dir = File.expand_path("../../..", __FILE__)


# rackup DefaultRackup

# Default to production
rails_env = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || "development"
environment rails_env

if rails_env == 'development'
  workers 1
  bind 'tcp://0.0.0.0:#{port}'
else
  # https://github.com/seuros/capistrano-puma/blob/642d141ee502546bd5a43a76cd9f6766dc0fcc7a/lib/capistrano/templates/puma.rb.erb#L25
  prune_bundler
  preload_app!
  # Change to match your CPU core count
  workers 1
  #{'shared_dir = "#{base_dir}/shared"'}
  # Set up socket location
  #bind 'tcp://0.0.0.0:4000'
  #{'bind "unix://#{shared_dir}/tmp/puma/socket"'}
  # Logging
  #{'stdout_redirect "#{shared_dir}/log/puma.stdout.log", "#{shared_dir}/log/puma.stderr.log", true'}
  # Set master PID and state locations
  #{'pidfile "#{shared_dir}/tmp/puma/pid"'}
  #{'state_path "#{shared_dir}/tmp/puma/state"'}
  activate_control_app
  on_restart do
    puts 'Refreshing Gemfile'
    #{'ENV["BUNDLE_GEMFILE"] = "#{current_dir}/Gemfile" unless rails_env == \'development\''}
  end
  #{"#mongoid reconnects by itself" if mongoid}
  #{'on_worker_boot do
    require "active_record"
    ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
    ActiveRecord::Base.establish_connection(YAML.load_file("#{base_dir}/current/config/database.yml")[rails_env])
  end' if !mongoid}
end

TEXT
end

remove_file 'app/views/layouts/application.html.erb'


remove_file 'config/application.rb'
create_file 'config/application.rb' do <<-TEXT
require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require "active_model/railtie"
#{'#' if mongoid}require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module #{app_name.camelize}
  class Application < Rails::Application
    config.generators do |g|
      g.test_framework :rspec
      g.view_specs false
      g.helper_specs false
      g.feature_specs false
      g.template_engine :slim
      g.stylesheets false
      g.javascripts false
      g.helper false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
    end

    config.i18n.locale = :ru
    config.i18n.default_locale = :ru
    config.i18n.available_locales = [:ru, :en]
    config.i18n.enforce_available_locales = true
    #{'config.active_record.schema_format = :sql' unless mongoid}

    #{'config.autoload_paths += %W(#{config.root}/extra)'}
    #{'config.eager_load_paths += %W(#{config.root}/extra)'}

    config.time_zone = 'Europe/Moscow'
    config.assets.paths << Rails.root.join("app", "assets", "fonts")
  end
end

TEXT
end

remove_file 'app/assets/javascripts/application.js'
create_file 'app/assets/javascripts/application.js' do <<-TEXT
TEXT
end

remove_file 'app/assets/javascripts/application.css'
create_file 'app/assets/javascripts/application.css' do <<-TEXT
TEXT
end


if mongoid
  FileUtils.cp(Pathname.new(destination_root).join('config', 'mongoid.yml').to_s, Pathname.new(destination_root).join('config', 'mongoid.yml.example').to_s)
else
  FileUtils.cp(Pathname.new(destination_root).join('config', 'database.yml').to_s, Pathname.new(destination_root).join('config', 'database.yml.example').to_s)
end

FileUtils.cp(Pathname.new(destination_root).join('config', 'secrets.yml').to_s, Pathname.new(destination_root).join('config', 'secrets.yml.example').to_s)

unless mongoid
  generate "paper_trail:install", "--with-associations"
  generate "friendly_id"
  rake "db:migrate"
end

if yarn
  run 'yarn install'
else
  run 'npm install'
end

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }
