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
    http = Net::HTTP.new(url.host, url.port)

    request2 = Net::HTTP::Get.new(url)
    request2['authorization'] = "#{token_type} #{access_token}"

    response2 = http.request(request2)
    if response2.message == 'OK'
      vers = JSON.parse(response2.read_body)
      Setting.transaction do
        last_version_id = Setting.key_get_value('last_version_id')
        while vers.present?
          h = vers.shift
          last_version_id = h['id'].to_i
          case h['event']
          when 'create'
            args = Hash[YAML.load(h['object_changes']).to_a.map { |v| [v[0], v[1][1]] }]
            args['data'] = YAML.load(args['data']) if args['data'].present?
            begin
              obj = h['item_type'].constantize.where(id: args['id']).first
              if obj.present?
                obj.update(args)
              else
                h['item_type'].constantize.create(args)
              end
            rescue StandardError => e
              e
            end
          when 'update'
            args = YAML.load(h['object'])
            args['data'] = YAML.load(args['data']) if args['data'].present?
            begin
              obj = h['item_type'].constantize.where(id: args['id']).first
              if obj.present?
                obj.update(args)
              else
                obj = h['item_type'].constantize.new
                obj.id = h['item_id']
                obj.save!
                obj.update(args)
              end
            rescue StandardError => e
              e
            end
          when 'destroy'
            begin
              h['item_type'].constantize.find(h['item_id']).delete
            rescue StandardError => e
              e
            end
          else
            # type code here
            Raise 'FatalProtocolError'
          end
        end
        #Version.sequence_reset
        Setting.key_set_value('last_version_id', last_version_id)
      end
    end
  end
end
