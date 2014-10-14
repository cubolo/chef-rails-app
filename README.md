Rails App Cookbook
======================

This Chef repository aims at being the easiest way set up and configure your own Rails server
to host one or more Ruby on Rails applications using best
practices from our community.


## Features

Takes care of automatic installation and configuration of the following software
on a single server or multiple servers:

* nginx webserver
* Puma or Unicorn for running Ruby on Rails
* Multiple apps and evironments on one server
* Database creation and password generation
* Easy SSL configuration
* Deployment with Mina or Capistrano

## Supported Ubuntu versions

* Ubuntu 12.04 LTS
* Ubuntu 14.04 LTS

## Supported databases

* MongoDB
* MySQL

## Getting started

The following paragraphs will guide you to set up your own server to host Ruby on Rails applications.

### Installation

Clone the repository onto your own workstation.

```sh
$ git clone git://github.com/cubolo/chef-rails-app.git rails_app
```

Run bundle:

```sh
$ bundle install
```

### Prepare all the cookbooks

```
$ bundle exec librarian-chef install
```

### Setting up the server

Prepare the server with `knife solo`. This installs Chef on the server.

```sh
bundle exec knife solo prepare <your user>@<your host/ip>
```

Install everything to run Rails apps on your server with the next command. You might need to enter your password a couple of times.

```sh
bundle exec knife solo cook <your user>@<your host/ip>
```

### Deploying your applications

Applications are deployed using mina but capistrano should work as well.

In short you need to do the following:

- Ensure you have a rbenv .ruby-version in your application which specifies the Ruby version to use.
- Add Mina to your applicationa's Gemfile.

So, let's get started.

The folder structure for each app on your server looks like:

```
/u/apps/your_app
  current/
  releases/
  shared/
    config/
      database.yml
      unicorn.rb
    pids/
    log/
    sockets/
```

## Resources and original authors

* Most of the cookbooks that are used in this repository are installed from the [Opscode Community Cookbooks](http://community.opscode.com).