require "net/http"
# == Schema Information
#
# Table name: ion_contents
#
#  id              :bigint           not null, primary key
#  data            :text
#  deep_scraped_at :datetime
#  hidden          :boolean          default(FALSE), not null
#  html            :text
#  level           :string
#  position        :integer
#  scraped_at      :datetime
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ion_content_id  :integer
#  page_id         :integer
#
class IonContent < ApplicationRecord
  has_many :ion_modules, -> { order("position") }

  serialize :data, coder: JSON, type: Hash

  DEBUG = false

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data = JSON.parse(h.to_json)
    # save!
  end

  def self.base_url
    "https://103.sb.mywebsite-editor.com/app/261452211/"
  end

  def self.scrape_images
    IonModule.where(module_type: %w[textWithImage imageSubtitle gallery]).each do |mod|
      try do
        doc = Nokogiri::HTML(mod.html)
        images = []
        doc.css("img").each do |img|
          url_img = img["src"]
          next unless url_img.present?

          url_img =~ %r{/((?:thumb/)?\d+\.(?:jpg|jpeg|png))}i
          image_name_matcher = url_img.match(%r{/(\d+\.(?:jpg|jpeg|png))}i)
          if image_name_matcher.present?
            image_name = image_name_matcher[1]
            image_file_name = "#{Rails.root}/doc/NDBV_DE/images/#{image_name}"
            url_img_public = "https://www.ndbv.de/s/cc_images/cache_#{image_name}"
            if File.exist?(image_file_name)
              images.push(image_name)
            else
              res, image = get_ioc(url_img_public, { referer: "919568183/", read_file: true })
              if res.message == "OK"
                File.binwrite(image_file_name, image)
                images.push(image_name)
              else
                Rails.logger.info "Problem in IonModule[#{mod.module_id} of IonContent[#{mod.ion_content_id}] with img - no image #{image_file_name}"
              end
            end
          else
            Rails.logger.info "Problem in IonModule[#{mod.module_id} of IonContent[#{mod.ion_content_id}] with img - no src"
          end
        end
        mod.deep_merge_data!(mod.module_type => images.to_json)
        mod.save!
      rescue StandardError => e
        Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
      end
    end
  end

  def self.scrape_downloads
    IonModule.where(module_type: ["downloadDocument"]).each do |mod|
      doc = Nokogiri::HTML(mod.html)
      file_name = doc.css(".rightDownload a")[0].text.strip
      url = "https://www.ndbv.de/app/download/#{mod.module_id}/" + CGI.escape(file_name)
      dl_file_name = "#{Rails.root}/doc/NDBV_DE/download/#{file_name}"
      next if File.exist?(dl_file_name)

      res, download = get_ioc(url, { read_file: true })
      if res.message == "OK"
        try do
          File.binwrite(dl_file_name, download)
          mod.deep_merge_data!(mod.module_type => file_name)
          mod.save!
        rescue StandardError => e
          Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
        end
      else
        Rails.logger.info "Problem in IonModule[#{mod.module_id} of IonContent[#{mod.ion_content_id}] with img - no image #{image_file_name}"
      end
    end
  end

  def self.scrape_website
    # get news page as entry
    res, doc = get_ioc(base_url + "919568183/", { referer: "919568183/" })
    if res.message == "OK"
      @ion_content = IonContent.find_or_create_by(page_id: 919_568_183)
      args = {
        "html" => doc.to_html,
        "title" => doc.css("#content_area h1")[0].text,
        "scraped_at" => Time.now
      }
      @ion_content.update(args)
    end
    # get top navi links
    doc.css("#navigation #mainNav1 > li > a").each_with_index do |nav_entry, ix|
      page_id = nav_entry["data-page-id"].to_i
      content = IonContent.find_or_create_by(page_id: page_id)
      content.update(title: nav_entry.text, position: ix, level: nav_entry["class"])
    end
    IonContent.order(position: :asc).all.each do |content|
      next if content.scraped_at.present?

      res2, doc2 = get_ioc(base_url + "#{content.page_id}/", { referer: "919568183/" })
      next unless res2.message == "OK"

      content2 = IonContent.find_or_create_by(page_id: content.page_id)
      args = {
        "html" => doc2.to_html,
        "title" => doc2.css("#content_area h1")[0].andand.text,
        "scraped_at" => Time.now
      }
      content2.update(args)
      # sleep(1)
    end

    # Scrape Level 2 Content
    IonContent.order(position: :asc).all.each do |content|
      doc4 = Nokogiri::HTML(content.html)
      doc4.css("#navigation #mainNav2 > li > a").each_with_index do |nav_entry, ix|
        page_id = nav_entry["data-page-id"].to_i
        content2 = IonContent.find_or_create_by(page_id: page_id)
        content2.update(title: nav_entry.text, ion_content_id: content.id, position: ix, level: nav_entry["class"])
      end
    end

    IonContent.order(position: :asc).all.each do |content|
      next if content.scraped_at.present?

      res2, doc2 = get_ioc(base_url + "#{content.page_id}/", { referer: "919568183/" })
      next unless res2.message == "OK"

      content2 = IonContent.find_or_create_by(page_id: content.page_id)
      args = {
        "html" => doc2.to_html,
        "title" => doc2.css("#content_area h1")[0].andand.text,
        "scraped_at" => Time.now,
        "ion_content_id" => content.id
      }
      content2.update(args)
      # sleep(1)
    end

    # Scrape Content Modules
    IonContent.order(position: :asc).all.each do |content|
      next if content.deep_scraped_at.present?

      doc3 = Nokogiri::HTML(content.html)
      doc3.css("#content_area .modulelt").each_with_index do |mod, ix3|
        module_id = mod["data-moduleid"].strip
        ion_module = IonModule.find_or_create_by(module_id: module_id)
        args = {
          "html" => mod.inner_html.strip,
          "module_type" => mod["data-moduletype"],
          "position" => ix3,
          "ion_content_id" => content.id
        }
        ion_module.update(args)
      end
      content.update(deep_scraped_at: Time.now)
    end
  end

  # curl 'https://103.sb.mywebsite-editor.com/app/261452211/919568183/' \
  #   -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  #   -H 'Accept-Language: de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6' \
  #   -H 'Connection: keep-alive' \
  #   -H 'Cookie: historyManager=%2C0; DIY_SB=satkbq4j3c8qvrf35thlp7ttvjndj5sp' \
  #   -H 'Referer: https://103.sb.mywebsite-editor.com/app/261452211/919568183/' \
  #   -H 'Sec-Fetch-Dest: document' \
  #   -H 'Sec-Fetch-Mode: navigate' \
  #   -H 'Sec-Fetch-Site: same-origin' \
  #   -H 'Sec-Fetch-User: ?1' \
  #   -H 'Upgrade-Insecure-Requests: 1' \
  #   -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36' \
  #   -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="102", "Google Chrome";v="102"' \
  #   -H 'sec-ch-ua-mobile: ?0' \
  #   -H 'sec-ch-ua-platform: "macOS"' \
  #   --compressed
  #
  #
  #   curl 'https://103.sb.mywebsite-editor.com/app/261452211/919568183/' \
  #   -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  #   -H 'Accept-Language: de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6' \
  #   -H 'Cache-Control: max-age=0' \
  #   -H 'Connection: keep-alive' \
  #   -H 'Cookie: DIY_SB=6d43g9lgh8l19p9ajrisicc5u9ir3bn9; historyManager=%2C0' \
  #   -H 'Referer: https://103.sb.mywebsite-editor.com/app/261452211/919568183/' \
  #   -H 'Sec-Fetch-Dest: document' \
  #   -H 'Sec-Fetch-Mode: navigate' \
  #   -H 'Sec-Fetch-Site: same-origin' \
  #   -H 'Sec-Fetch-User: ?1' \
  #   -H 'Upgrade-Insecure-Requests: 1' \
  #   -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36' \
  #   -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="102", "Google Chrome";v="102"' \
  #   -H 'sec-ch-ua-mobile: ?0' \
  #   -H 'sec-ch-ua-platform: "macOS"' \
  #   --compressed > 919568183.html

  def self.get_ioc(url, get_options = {}, _opts = {})
    read_file = get_options.delete(:read_file)
    referer = base_url + get_options.delete(:referer).to_s
    Rails.logger.debug "[get_ioc] GET with payload #{get_options}" if DEBUG
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data(get_options)
    # instantiate a new Request object
    req = Net::HTTP::Get.new(uri.path + ("?" unless /\?$/.match?(uri.path)).to_s + req.body)
    unless read_file
      req["cookie"] = "historyManager=%2C0; DIY_SB=1erupk18fj910iqj9k8dafimpmuq7v2s"
      req["referer"] = referer if referer.present?
    end
    res = http.request(req)

    doc = if read_file
            res.body
          elsif res.message == "OK"
            Nokogiri::HTML(res.body)
          else
            Nokogiri::HTML(res.message)
          end
    [res, doc]
  end
end
