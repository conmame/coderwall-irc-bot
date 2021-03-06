# -*- coding:utf-8 -*-
require 'net/irc'
require 'yaml'
require 'daemon_spawn'
require 'coderwaller'
require_relative '../lib/coderwall_team'

class UserNotFoundException < Exception; end

class CoderwallIrcBot < Net::IRC::Client
  include CoderWaller

  def initialize(host, port, opts={})
    @password = (opts[:password].nil?) ? '' : opts[:password]
    @team_id = (opts[:team_id].nil?) ? '' : opts[:team_id]
    super
  end

  def on_rpl_welcome(m)
    post_irc(opts.channel, @password, JOIN)
  end

  def on_privmsg(m)
    channel, message = *m
    p = -> msg { post_irc(channel, msg) }

    begin
      case message.force_encoding('utf-8')
      when /^coderwall:\s*(\w+)/
        coderwall_user_status($1) do |msg|
          p.call(msg)
        end
      when /^coderwall-d:\s*(\w+)/
        coderwall_user_detail_status($1) do |msg|
          p.call(msg)
        end
      when /^coderwall-t[:]?\s*(\w*)/
        tid = ($1.nil? || $1 == '') ? @team_id : $1
        coderwall_team_status(tid) do |msg|
          p.call(msg)
        end
      end
    rescue UserNotFoundException => e
      p.call(e.message)
    end
  end

  private
  def post_irc(channel, msg, type = NOTICE)
    post(type, channel, msg)
  end

  def coderwall_user_status(user_name)
    user_achievement = get_coderwall(user_name)
    yield "#{user_achievement[:name]} has #{user_achievement[:badges].size} badges! http://coderwall.com/#{user_achievement[:name]}" if block_given?
  end

  def coderwall_user_detail_status(user_name)
    user_achievement = get_coderwall(user_name)
    yield "#{user_name} have 0 badge" if user_achievement[:badges].size == 0 if block_given?
    user_achievement[:badges].each do |badge|
      yield "* #{badge.name} (#{badge.description})" if block_given?
    end
  end

  def coderwall_team_status(team_id)
    team_ranking = CoderwallTeam::get_team_rank(team_id)
    yield team_ranking if block_given?
  end

  def get_coderwall(user_name)
    user_achievement = CoderwallerApi.get_user_achievement(user_name)
    raise(UserNotFoundException, user_achievement[:msg]) unless user_achievement[:msg] == ''
    user_achievement
  end
end

class Cib < DaemonSpawn::Base
  def start(args)
    puts "start : #{Time.now}"
    log = Logger.new(STDOUT)
    log.level = Logger::ERROR
    server_config = YAML.load_file("../config/config.yaml")['server']
    client = CoderwallIrcBot.new(server_config['host'], server_config['port'],
      {:nick => server_config['nick'], :user => server_config['user'], :real => server_config['real'],
      :channel => server_config['channel'], :password => server_config['password'], :team_id => server_config['coderwall_team_id'] , :logger => log})
      client.start
    end

    def stop
      puts "stop  : #{Time.now}"
    end
  end

  Cib.spawn!({
    :working_dir => File.dirname(__FILE__),
    :pid_file => File.expand_path(File.dirname(__FILE__) + '/../tmp/cib.pid'),
    :log_file => File.expand_path(File.dirname(__FILE__) + '/../log/cib.log'),
    :sync_log => true,
    :singleton => true
  })
