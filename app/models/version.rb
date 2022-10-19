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

  def self.list_sequence
    sql = <<-SQL
SELECT 'SELECT NEXTVAL(' ||
       quote_literal(quote_ident(PGT.schemaname) || '.' || quote_ident(S.relname)) ' ) FROM ' ||
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
      ActiveRecord::Base.connection.execute(query['query'])
    end
  end

  def self.get_max_ids
    tables = File.read("#{Rails.root}/db/schema.rb").split("\n").select{|l| l =~ /create_table/ }.map do |line|
      line.match(/\"(.*)\"/)[1]
    end
    localized_tables = []
    out = []
    tables.each do |line|
      class_name = line.camelcase.singularize
      max_id = class_name.constantize.order(:id).last.id rescue nil
      localized_tables.push(class_name) if max_id.to_i > Setting::MIN_ID
      out.push("#{line}: #{max_id}")
    end
    [out, localized_tables]
  end

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
      # if query['query'] =~ /_ccs_id/
      #   query['query'].gsub!("#{Tournament::MIN_ID}", "1")
      # end
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
          if h['item_type'] == "PartyCc" #TODO what's going on here?
            args['data'] = eval(args['data']) if args['data'].present? && args['data'].is_a?(String)
          else
            args['data'] = YAML.load(args['data']) if args['data'].present?
          end
          args['remarks'] = YAML.load(args['remarks']) if args['remarks'].present?
          Rails.logger.info "#{h['item_type']}[#{h['item_id']}]#{JSON.pretty_generate(args)}"
          begin
            classz = h['item_type'].constantize
            item_id = h['item_id']
            obj = nil
            if h['item_type'] == "GameParticipations"
              obj = classz.where(game_id: args['game_id'], player_id: args['player_id'], role: args['role']).first
            elsif h['item_type'] == "Player"
              obj = classz.where(type: nil).where(ba_id: args['ba_id']).first
              (obj ||= classz.where(cc_id: args['cc_id']).first) if args['cc_id'].present?
            elsif h['item_type'] == "SeasonParticipation"
              obj = classz.where(player_id: args['player_id'], club_id: args['club_id'], season_id: args['season_id']).first

              obj.andand.update_columns(id: h['item_id'])
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
              if h['item_type'] == "SeasonParticipation"
                oo = classz.where(player_id: args['player_id'], club_id: args['club_id'], season_id: args['season_id']).first
                if oo.present?
                  oo.update_columns(id: h['item_id'])
                  next
                end
              end
              args.each do |k,v|
                obj.write_attribute(k, v)
              end
              if obj.valid?
                obj.update_columns(args)
              else
                raise StandardError, msg: "tryiung to update from invalid record"
              end
            else
              h['item_type'].constantize.create(args)
            end
          rescue StandardError => e
            Rails.logger.info "#{e} #{e.backtrace.inspect}"
            return
          end
        when 'update'
          args = h['object_changes'].present? ? Hash[YAML.load(h['object_changes']).to_a.map { |v| [v[0], v[1][1]] }] : YAML.load(h["object"])
          if h['item_type'] == "PartyCc" #TODO what's going on here?
            args['data'] = eval(args['data']) if args['data'].present? && args['data'].is_a?(String)
          else
            args['data'] = YAML.load(args['data']) if args['data'].present?
          end
          args['remarks'] = YAML.load(args['remarks']) if args['remarks'].present?
          begin
            classz = h['item_type'].constantize
            obj = classz.where(id: h['item_id']).first
            if obj.present?
              args.each do |k,v|
                obj.write_attribute(k, v)
              end
              if obj.valid?
                if h['item_type'] == "SeasonParticipation"
                  oo = classz.where(player_id: args['player_id'], club_id: args['club_id'], season_id: args['season_id']).first
                  if oo.present? && oo.id != obj.id
                    oo.update_columns(id: h['item_id'])
                    next
                  end
                end
                obj.update_columns(args)
              else
                args = YAML.load(h["object"])
                args['data'] = YAML.load(args['data']) if args['data'].present?
                args['remarks'] = YAML.load(args['remarks']) if args['remarks'].present?
                obj.update_columns(args)
              end
            else
              obj = h['item_type'].constantize.new
              obj.id = h['item_id']
              args = YAML.load(h["object"])
              args['data'] = YAML.load(args['data']) if args['data'].present?
              args['remarks'] = YAML.load(args['remarks']) if args['remarks'].present?

              args.each do |k,v|
                obj.write_attribute(k, v)
              end
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
