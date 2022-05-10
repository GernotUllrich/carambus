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
      deletes = []
      creates = []
      last_version_id = Setting.key_get_value('last_version_id')
      while vers.present?
        ix = 0
        Setting.transaction do
          while ix < 100
            ix = ix +1
            h = vers.shift
            break if h.blank?
            last_version_id = h.andand['id'].to_i
            case h['event']
            when 'create'
              args = Hash[YAML.load(h['object_changes']).to_a.map { |v| [v[0], v[1][1]] }]
              args['data'] = YAML.load(args['data']) if args['data'].present?
              begin
                classz = h['item_type'].constantize
                item_id = h['item_id']
                obj = classz.where(id: item_id).first
                if obj.present?
                  obj.update(args)
                else
                  #TODO look for uniq keys in args only (refine except)
                  h['item_type'].constantize.where(args.except("id", "created_at", "updated_at")).each.map do |o|
                    deletes.push([h['item_type'], args["id"]])
                  end
                  if h['item_type'] == "Seeding"
                    h['item_type'].constantize.where(args.except("player_id", "tournament_id")).each.map do |o|
                      deletes.push([h['item_type'], args["id"]])
                    end
                    h['item_type'].constantize.where(args.except("id")).each.map do |o|
                      deletes.push([h['item_type'], args["id"]])
                    end
                  end
                  obj = h['item_type'].constantize.new(args)
                  creates.push([h['item_type'], args])
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
                  obj.update(args)
                else
                  obj = h['item_type'].constantize.new
                  obj.id = h['item_id']
                  obj.assign_attributes(args)
                  obj.save!
                end
              rescue StandardError => e
                Rails.logger.info "#{e} #{e.backtrace.inspect}"
              end
            when 'destroy'
              begin
                obj = h['item_type'].constantize.where(id: h['item_id']).first
                obj.andand.delete
              rescue StandardError => e
                Rails.logger.info "#{e} #{e.backtrace.inspect}"
              end
            else
              # type code here
              Rails.logger.info "FatalProtocolError"
              Raise 'FatalProtocolError'
            end
          end
        end
        if deletes.present?
          todo = deletes.dup.to_set
          deletes.each do |del|
            del[0].constantize.where(id: del[1]).first.delete rescue nil
            todo -= del
          end
          deletes = todo
        end
        if creates.present?
          todo = creates.dup.to_set
          creates.each do |crt|
            crt[0].constantize.create(crt[1]) rescue nil
            todo -= crt
          end
          creates = todo
        end
        #Version.sequence_reset
        Setting.key_set_value('last_version_id', last_version_id)
      end
    end
  end
end
