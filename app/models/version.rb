# frozen_string_literal: true

require "uri"
require "net/http"
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
#  region_ids     :integer          :default: [], array: true
#
# Indexes
#
#  index_versions_on_item_type_and_item_id  (item_type,item_id)
#
class Version < PaperTrail::Version
  belongs_to :region, optional: true

  self.ignored_columns = ["region_ids"]
  # This scope finds all versions where:
  # 1. region_ids is nil OR
  # 2. region_ids is an empty array OR
  # 3. region_ids contains the given region_id
  scope :for_region, ->(region_id) {
    where("region_ids IS NULL OR region_ids = '{}' OR region_ids @> ARRAY[?]::integer[]", region_id)
  }

  def self.relevant_for_region?(region_id)
    return true if region_ids.nil? || region_ids.empty?
    region_ids.include?(region_id)
  end

  def self.list_sequence
    sql = <<~SQL
      SELECT 'SELECT NEXTVAL(' ||
             pg_catalog.quote_literal(pg_catalog.quote_ident(PGT.schemaname) || '.' || pg_catalog.quote_ident(S.relname)) || ' ) FROM ' ||
             pg_catalog.quote_ident(PGT.schemaname) || '.' || pg_catalog.quote_ident(T.relname) || ';' as query
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
      ActiveRecord::Base.connection.execute(query["query"])
    end
  end

  def self.update_carambus
    url = URI("#{Carambus.config.carambus_api_url}/versions/current_revision")
    Rails.logger.info ">>>>>>>>>>>>>>>> GET #{url} <<<<<<<<<<<<<<<<"
    uri = URI(url)
    json_io = Net::HTTP.get(uri)
    vers = JSON.parse(json_io)
    revision = vers["current_revision"]
    my_revision = `cat #{Rails.root}/REVISION`.strip
    if my_revision != revision
      result = `REVISION=#{revision} bash -x #{Rails.root}/bin/deploy.sh 2>&1`
      Rails.logger.info(result)
    else
      Rails.logger.info("carambus version is up-to-date (#{revision})")
    end
  end

  def self.max_ids
    tables = File.read("#{Rails.root}/db/schema.rb").split("\n").select { |l| l =~ /create_table/ }.map do |line|
      line.match(/"(.*)"/)[1]
    end
    localized_tables = []
    out = []
    tables.each do |line|
      class_name = line.camelcase.singularize
      begin
        max_id = class_name.constantize.order(:id).last.id
      rescue StandardError
        max_id = nil
      end
      localized_tables.push(class_name) if max_id.to_i > Setting::MIN_ID
      out.push("#{line}: #{max_id}")
    end
    [out, localized_tables]
  end

  def self.sequence_reset
    if local_server?
      sql = <<~SQL
        SELECT 'SELECT SETVAL(' ||
               quote_literal(quote_ident(PGT.schemaname) || '.' || quote_ident(S.relname)) ||
               ', GREATEST(COALESCE(MAX(' ||quote_ident(C.attname)|| '), 1), ' ||
               'CASE WHEN ''' || T.relname || ''' = ''tournaments'' THEN 50000000 ' ||
               'ELSE 50000000 END) ) FROM ' ||
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
        ActiveRecord::Base.connection.execute(query["query"])
      end
    else
      # destroy all records with local ids
      ActiveRecord::Base.connection.tables.each do |table_str|
        begin
          count = table_str.singularize.camelize.constantize.where("id > 50000000").count
        rescue StandardError
          count = 0
        end
        table_str.singularize.camelize.constantize.where("id > 50000000").to_a.map(&:destroy) if count.positive?

        begin
          result = ActiveRecord::Base.connection.exec_query("SELECT MAX(id) FROM #{table_str}")
        rescue StandardError
          result = nil
        end
        max_id = result.rows.first.first if result.present?
        next unless max_id.present?

        begin
          ActiveRecord::Base.connection.exec_query("SELECT setval('#{table_str}_id_seq', #{max_id + 1})")
        rescue StandardError
          # Ignored
        end
      end
    end
  end

  def self.last_version
    return Version.last.id if Carambus.config.carambus_api_url.blank?

    url = "#{Carambus.config.carambus_api_url}/versions/last_version"
    uri = URI(url)
    json_io = Net::HTTP.get(uri)
    JSON.parse(json_io)["last_version"]
  rescue OpenURI::HTTPError => e
    Rails.logger.info "===== #{e} cannot read from #{url}"
    e.to_s
  end

  def self.update_from_carambus_api(opts = {})
    tournament_id = opts[:update_tournament_from_cc]
    region_id = opts[:reload_tournaments]
    region_id ||= opts[:reload_leagues]
    region_id ||= opts[:reload_leagues_with_details]
    region_id ||= opts[:update_region_from_cc]
    league_id = opts[:update_league_from_cc]
    club_id = opts[:update_club_from_cc]
    force = opts[:force]
    player_details = opts[:player_details]
    league_details = opts[:league_details]
    # access_token, token_type = Setting.get_carambus_api_token
    url = URI("#{Carambus.config.carambus_api_url}/versions/get_updates?last_version_id=#{
      Setting.key_get_value("last_version_id").to_i
    }#{
      "&update_tournament_from_cc=#{tournament_id}" if tournament_id.present?
    }#{
      "&reload_tournaments=#{region_id}" if opts[:reload_tournaments].present?
    }#{
      "&reload_leagues=#{region_id}" if opts[:reload_leagues].present?
    }#{
      "&reload_leagues_with_details=#{region_id}" if opts[:reload_leagues_with_details].present?
    }#{
      "&update_region_from_cc=#{region_id}" if opts[:update_region_from_cc].present?
    }#{
      "&update_club_from_cc=#{club_id}" if club_id.present?
    }#{
      "&update_league_from_cc=#{league_id}" if league_id.present?
    }#{
      "&force=#{force}" if force
    }#{
      "&player_details=#{player_details}" if player_details
    }#{
      "&region_id=#{opts[:region_id]}" if opts[:region_id].present?
    }#{
      "&league_details=#{league_details}" if league_details
    }&season_id=#{Season.current_season&.id}")
    Rails.logger.info ">>>>>>>>>>>>>>>> GET #{url} <<<<<<<<<<<<<<<<"
    uri = URI(url)
    json_io = Net::HTTP.get(uri)
    vers = JSON.parse(json_io)
    while vers.present?
      h = vers.shift
      break if h.blank?
      begin
        ActiveRecord::Base.transaction do
          last_version_id = h.andand["id"].to_i
          case h["event"]
          when "create"
            args = YAML.load(h["object_changes"]).to_a.map { |v| [v[0], v[1][1]] }.to_h
            if h["item_type"] == "PartyCc" # TODO: what's going on here?
              args["data"] = eval(args["data"]) if args["data"].present? && args["data"].is_a?(String)
            elsif args["data"].present?
              args["data"] = YAML.load(args["data"])
            end
            args["remarks"] = YAML.load(args["remarks"]) if args["remarks"].present?
            Rails.logger.info "#{h["item_type"]}[#{h["item_id"]}]#{JSON.pretty_generate(args)}"
            begin
              classz = h["item_type"].constantize
              item_id = h["item_id"]
              obj = nil
              case h["item_type"]
              when "GameParticipations"
                obj = classz.where(game_id: args["game_id"], player_id: args["player_id"], role: args["role"]).first
              when "Player"
                obj = nil
                (obj ||= classz.where(type: nil).where(ba_id: args["ba_id"]).first) if args["ba_id"].present?
              when "SeasonParticipation"
                obj = classz.where(player_id: args["player_id"], club_id: args["club_id"],
                                   season_id: args["season_id"]).first
                if obj.present?
                  obj.update_columns(id: h["item_id"])
                  next
                end
              else
                # ignore
              end
              if obj.present?
                Rails.logger.info obj.attributes.to_s
                if obj.id != args["id"] && obj.id < 5_000_000
                  Rails.logger.info "must merge #{h["item_type"]}[#{obj.id}] in source first!!!"
                  puts "must merge #{h["item_type"]}[#{obj.id}] in source first!!!"
                  return
                  # raise ArgumentError, "must merge in source first!!!"
                end
              else
                obj = classz.where(id: item_id).first
              end
              if obj.present?
                if h["item_type"] == "SeasonParticipation"
                  oo = classz.where(player_id: args["player_id"], club_id: args["club_id"],
                                    season_id: args["season_id"]).first
                  if oo.present?
                    oo.update_columns(id: h["item_id"])
                    next
                  end
                end
                args.each do |k, v|
                  obj.write_attribute(k, v)
                end
                raise StandardError, msg: "trying to update from invalid record" unless obj.valid?

                obj.update_columns(args)
              else
                h["item_type"].constantize.create(args.merge(unprotected: true))
                Rails.logger.info "Created #{h["item_type"]} with #{args.inspect}"
              end
            rescue StandardError => e
              Rails.logger.info "#{e} #{e.backtrace.inspect}"
              return
            end
          when "update"
            args = if h["object_changes"].present?
                     YAML.load(h["object_changes"])
                         .to_a.map { |v| [v[0], v[1][1]] }.to_h
                   else
                     YAML.load(h["object"])
                   end
            if h["item_type"] == "PartyCc" # TODO: what's going on here?
              args["data"] = eval(args["data"]) if args["data"].present? && args["data"].is_a?(String)
            elsif args["data"].present?
              args["data"] = YAML.load(args["data"])
            end
            args["remarks"] = YAML.load(args["remarks"]) if args["remarks"].present?
            args["t_ids"] = YAML.load(args["t_ids"]) if args["t_ids"].present?
            begin
              classz = h["item_type"].constantize
              obj = classz.where(id: h["item_id"]).first
              if obj.present?
                args.each do |k, v|
                  obj.write_attribute(k, v)
                end
                if obj.valid?
                  if h["item_type"] == "SeasonParticipation"
                    oo = classz.where(player_id: args["player_id"], club_id: args["club_id"],
                                      season_id: args["season_id"]).first
                    if oo.present? && oo.id != obj.id
                      oo.update_columns(id: h["item_id"])
                      next
                    end
                  end
                else
                  args = YAML.load(h["object"])
                  args["data"] = YAML.load(args["data"]) if args["data"].present?
                  args["remarks"] = YAML.load(args["remarks"]) if args["remarks"].present?
                end
                obj.update_columns(args)
              else
                obj = h["item_type"].constantize.new
                obj.id = h["item_id"]
                args = YAML.load(h["object"])
                args["data"] = YAML.load(args["data"]) if args["data"].present?
                args["remarks"] = YAML.load(args["remarks"]) if args["remarks"].present?

                args.each do |k, v|
                  obj.write_attribute(k, v)
                end
                obj.unprotected = true
                obj.save!
                obj.unprotected = false
              end
            rescue StandardError => e
              Rails.logger.info "#{obj.andand.attributes} #{e} #{e.backtrace.inspect}"
            end
          when "destroy"
            begin
              obj = h["item_type"].constantize.where(id: h["item_id"]).first
              if obj.present?
                obj.unprotected = true
                obj.delete
              end
            rescue StandardError => e
              Rails.logger.info "#{obj.andand.attributes} #{e} #{e.backtrace.inspect}"
            end
          else
            # type code here
            Rails.logger.info "FatalProtocolError"
            raise "FatalProtocolError"
          end
          Setting.key_set_value("last_version_id", last_version_id)
        end
      rescue StandardError => e
        Rails.logger.info "===== FATAL #{e} #{e.backtrace} cannot continue"
      end
    end
  rescue OpenURI::HTTPError => e
    Rails.logger.info "===== #{e} cannot read from #{url}"
    e.to_s
  end

  def self.local_server?
    ApplicationRecord.local_server?
  end

  def self.local_from_api
    Version.sequence_reset if local_server
  end
end
