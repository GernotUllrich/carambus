# frozen_string_literal: true

require 'open-uri'
require 'uri'
require 'net/http'
# == Schema Information
#
# Table name: versions
#
#  id             :bigint           not null, primary key
#  event          :string
#  item_type      :string
#  object         :text
#  object_changes :text
#  whodunnit      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  item_id        :bigint
#
# Indexes
#
#  index_versions_on_item_type_and_item_id  (item_type,item_id)
#
class Version < ApplicationRecord
  def self.sequence_reset
    sql = <<~SQL
      SELECT 'SELECT SETVAL(' ||
             quote_literal(quote_ident(PGT.schemaname) || '.' || quote_ident(S.relname)) ||
             ', GREATEST(COALESCE(MAX(' ||quote_ident(C.attname)|| '), 1), CAST(50000000 AS BIGINT)) ) FROM ' ||
             quote_ident(PGT.schemaname)|| '.'||quote_ident(T.relname)|| ';' as query
      FROM pg_class AS S,
           pg_depend AS D,
           pg_class AS T,
           pg_attribute AS C,
           pg_tables AS PGT
      WHERE S.relkind = 'S'
          AND S.oid = D.objid
          AND D.refobjid = T.oid
          AND D.refobjid = C.attrelid
          AND D.refobjsubid = C.attnum
          AND T.relname = PGT.tablename
      ORDER BY S.relname;
    SQL

    ActiveRecord::Base.connection.execute(sql).each do |query|
      if query['query'] =~ /_ccs_id/
        query['query'].gsub!("#{Tournament::MIN_ID}", "1")
      end
      ActiveRecord::Base.connection.execute(query['query'])
    end
  end

  def self.update_from_carambus_api(opts = {})
    tournament_id = opts[:update_tournament_from_ba]
    region_id = opts[:update_region_from_ba]
    club_id = opts[:update_club_from_ba]
    player_details = opts[:player_details]
    access_token, token_type = Setting.get_carambus_api_token
    url = URI("#{Jumpstart.config.carambus_api_url}/versions/get_updates?last_version_id=#{
      Setting.key_get_value('last_version_id').to_i
    }#{
      "&update_tournament_from_ba=#{tournament_id}" if tournament_id.present?
    }#{
      "&update_region_from_ba=#{region_id}" if region_id.present?
    }#{
      "&update_club_from_ba=#{club_id}" if club_id.present?
    }#{
      "&player_details=#{player_details}" if player_details
    }")
    Rails.logger.info ">>>>>>>>>>>>>>>> GET #{url} <<<<<<<<<<<<<<<<"
    http = Net::HTTP.new(url.host, url.port)

    request2 = Net::HTTP::Get.new(url)
    request2['authorization'] = "#{token_type} #{access_token}"

    response2 = http.request(request2)
    if response2.message == 'OK'
      vers = JSON.parse(response2.read_body)
      deletes = {}
      creates = {}
      last_version_id = Setting.key_get_value('last_version_id')
      while vers.present?
        h = vers.shift
        break if h.blank?
        last_version_id = h.andand['id'].to_i
        case h['event']
        when 'create'
          args = Hash[YAML.load(h['object_changes']).to_a.map { |v| [v[0], v[1][1]] }]
          args['data'] = YAML.load(args['data']) if args['data'].present?
          Rails.logger.info "#{h['item_type']}[#{h['item_id']}]#{JSON.pretty_generate(args)}"
          begin
            classz = h['item_type'].constantize
            item_id = h['item_id']
            obj = nil
            if h['item_type'] == "GameParticipations"
              obj = classz.where(game_id: args['game_id'], player_id: args['player_id'], role: args['role']).first
            elsif h['item_type'] == "Player"
              obj = classz.where(ba_id: args['ba_id']).first
              (obj ||= classz.where(cc_id: args['cc_id']).first) if args['cc_id'].present?
            elsif h['item_type'] == "SeasonParticipation"
              obj = classz.where(player_id: args['player_id'], club_id: args['club_id'], season_id: args['season_id']).first
              { player_id: args['player_id'], club_id: args['club_id'], season_id: args['season_id'] }
              obj.update(id: h['item_id'])
              next
            end
            if obj.present?
              Rails.logger.info "#{obj.attributes}"
              if obj.id != args['id'] && obj.id < 5000000
                Rails.logger.info "must merge #{h['item_type']}[#{obj.id}] in source first!!!"
                puts "must merge #{h['item_type']}[#{obj.id}] in source first!!!"
                return
                #raise ArgumentError, "must merge in source first!!!"
              end
            else
              obj = classz.where(id: item_id).first
            end
            if obj.present?
              obj.update(args)
            else
              h['item_type'].constantize.create(args)
            end
          rescue StandardError => e
            Rails.logger.info "#{e} #{e.backtrace.inspect}"
            return
          end
        when 'update'
          args = h['object_changes'].present? ? Hash[YAML.load(h['object_changes']).to_a.map { |v| [v[0], v[1][1]] }] : YAML.load(h["object"])
          args['data'] = YAML.load(args['data']) if args['data'].present?
          begin
            obj = h['item_type'].constantize.where(id: h['item_id']).first
            if obj.present?
              obj.assign_attributes(args)
              if obj.valid?
                obj.update(args)
              else
                args = YAML.load(h["object"])
                args['data'] = YAML.load(args['data']) if args['data'].present?
                obj.update(args)
              end
            else
              obj = h['item_type'].constantize.new
              obj.id = h['item_id']
              obj.assign_attributes(args)
              obj.save!
            end
          rescue StandardError => e
            Rails.logger.info "#{e} #{e.backtrace.inspect}"
            return
          end
        when 'destroy'
          begin
            obj = h['item_type'].constantize.where(id: h['item_id']).first
            obj.andand.delete
          rescue StandardError => e
            Rails.logger.info "#{e} #{e.backtrace.inspect}"
            return
          end
        else
          # type code here
          Rails.logger.info "FatalProtocolError"
          raise 'FatalProtocolError'
          return
        end
        Setting.key_set_value('last_version_id', last_version_id)
      end
    end
  end
end
