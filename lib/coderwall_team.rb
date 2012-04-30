# -*- encode:utf-8 -*-
require 'mechanize'

class TeamIdNotGivenException < Exception; end

class CoderwallTeam
  def self.get_team_rank(team_id)
    begin
      raise(TeamIdNotGivenException, "Team ID(#{team_id}) is incorrect") unless not team_id.nil? && team_id =~ /^\w+$/

      agent = Mechanize.new { |a|
        a.user_agent_alias = 'Mac Safari'
        a.max_history = 0
      }

      agent.get("http://coderwall.com/teams/#{team_id}") do |page|
        team_name = page.title.split(':')[0]
        return "#{team_name}: " + (page/'//*[@class="your-rank"]/span').inner_html
      end
    rescue TeamIdNotGivenException => te
      return te.message
    rescue Exception => e
      return "Can't get team(#{team_id}) ranking"
    end
  end
end
