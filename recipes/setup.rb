#
# Cookbook Name:: rails_app
# Recipe:: default
#
# Copyright 2014, Matiss Kiris
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

deploy_user = node['rails_app']['user']
admin_user = node['rails_app']['admin']

node['rails_app']['apps'].each do |app, _app_info|

  app_data = data_bag_item('rails_apps', app)
  app_root = "/home/#{deploy_user}/apps/#{app}"

  app_data['environments'].each do |env, env_data|

    env_root = app_root + "/#{env}"
    env_enabled = env_data['enable'].nil? ? false : env_data['enable']

    # rbenv_ruby env_data['ruby_version']

    # rbenv_gem "bundler" do
    #   ruby_version env_data['ruby_version']
    # end

    directory "#{env_root}" do
      recursive true
      group deploy_user
      owner deploy_user
    end

    ['shared', 'shared/config', 'shared/sockets', 'shared/pids', 'shared/log', 'shared/system', 'releases', 'scm', 'tmp'].each do |dir|
      directory "#{env_root}/#{dir}" do
        recursive true
        group deploy_user
        owner deploy_user
      end
    end

    # Database config
    if env_data['database']

      adapter = env_data['database']['adapter']

      filename = adapter == 'mongoid' ? 'mongoid' : 'database'

      template "#{env_root}/shared/config/#{filename}.yml" do
        owner deploy_user
        group deploy_user
        mode 0600
        source "app_#{filename}.yml.erb"
        variables database_info: env_data['database'], rails_env: env
      end

    end

    # SSL

    if env_data['ssl_info']
      template "#{env_root}/shared/config/certificate.crt" do
        owner deploy_user
        group deploy_user
        mode 0644
        source 'app_cert.crt.erb'
        variables app_crt: env_data['ssl_info']['crt']
      end

      template "#{env_root}/shared/config/certificate.key" do
        owner deploy_user
        group deploy_user
        mode 0644
        source 'app_cert.key.erb'
        variables app_key: env_data['ssl_info']['key']
      end
    end

    # Nginx

    template "/etc/nginx/sites-available/#{app}_#{env}.conf" do
      owner admin_user
      group admin_user
      mode 00644
      variables(
        name: app,
        env: env,
        domain_names: env_data['domains'],
        enable_ssl: File.exist?("#{env_root}/shared/config/certificate.crt"),
        env_root: env_root,
        app_server: env_data['application_server'].nil? ? nil : env_data['application_server']['type']
      )
      source 'app_nginx.conf.erb'
      notifies :restart, 'service[nginx]', :delayed
    end

    # Application server

    if !env_data['application_server'].nil?
      app_server = env_data['application_server']['type']

      template "#{env_root}/shared/config/#{app_server}.rb" do
        mode 0644
        source "app_#{app_server}.rb.erb"
        variables name: app, env_root: env_root, deploy_user: deploy_user, number_of_workers: env_data['application_server']['number_of_workers'] || 1, threads: env_data['application_server']['threads'] || '1,2'
      end

      # Application server init script
      template "/etc/init.d/#{app}_#{env}_#{app_server}" do
        source "#{app_server}_init.sh.erb"
        owner 'root'
        group 'root'
        mode 00755
        variables(
          'name'             => app,
          'environment_root' => env_root,
          'environment'      => env,
          'deploy_user'      => deploy_user,
          'ruby_version'     => env_data['ruby_version']
        )
      end

      # Run application server at boot
      service "#{app}_#{env}_#{app_server}" do
        supports status: true, restart: true, reload: true
        action env_enabled ? :enable : :disable
      end

      # Restart application server
      if env_enabled && File.directory?("#{env_root}/current")
        service "#{app}_#{env}_#{app_server}" do
          action :restart
        end
      end

    end

    # Enable nginx site

    nginx_site "#{app}_#{env}.conf" do
      enable env_enabled
    end

    # Local domains

    env_data['local_domains'].each do |local|
      hostsfile_entry '127.0.0.1' do
        hostname local
        action   :append
      end
    end unless env_data['local_domains'].nil?

    # Monit

    if env_data['monit']

      template "/etc/monit/conf.d/#{app}_#{env}_#{app_server}.conf" do
        source "monit_#{app_server}.conf.erb"
        owner admin_user
        group admin_user
        mode 00644
        variables(
          'environment_root' => env_root,
          'app_name'         => app,
          'environment'      => env,
          'config'           => env_data
        )

        notifies :restart, 'service[monit]', :delayed
      end

   end

    # logrotate

    logrotate_app "rails-#{app}-#{env}" do
      cookbook "logrotate"
      path ["#{env_root}/current/log/*.log"]
      enable (env_enabled && !env_data['logrotate'].nil?)

      # Options
      if !env_data['logrotate'].nil?
        frequency env_data['logrotate']['frequency'] || "weekly"
        rotate env_data['logrotate']['rotate'] || 14
        compress env_data['logrotate']['rotate'].nil? ? false : env_data['logrotate']['rotate']
      end

      create "644 #{deploy_user} #{deploy_user}"
    end 

  end

end
