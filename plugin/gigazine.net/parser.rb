# coding: utf-8

require "uri"
require "rubygems"
require "nokogiri"

module Gigazine
  module Parser
    class ParseError < StandardError
    end

=begin
    def self.parse(src, url)
      return {
        :url            => url,
        :title          => self.extract_title(src),
        :published_time => self.extract_published_time(src),
        :images         => self.extract_images(src, url),
        :body           => self.extract_body(src),
      }
    end
=end

    def self.extract_title(src)
      doc = Nokogiri.HTML(src)
      return doc.xpath('//*[@id="maincol"]/div[@class="content"]/h1[@class="title"]/text()').text.strip
    end

    def self.extract_published_time(src)
      doc  = Nokogiri.HTML(src)
      time = doc.xpath('//*[@id="maincol"]/div[@class="content"]/h3[@class="date"]/text()').text.strip
      raise(ParseError, "invalid time") unless /(\d+)年(\d+)月(\d+)日 (\d+)時(\d+)分/ =~ time
      return Time.local($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i)
    end

=begin
    def self.extract_images(src, url)
      doc = Nokogiri.HTML(src)
      images = []
      images += doc.xpath('//*[@id="HeadLine"]//table[@class="ThmbColTb"]//p').map { |parag|
        img     = parag.xpath('.//img').first || next
        url     = URI.join(url, img[:src].strip).to_s
        caption = parag.xpath('./small/text()').text.strip
        {:url => url, :caption => caption}
      }.compact
      images += doc.xpath('//*[@id="HeadLine"]//div[@class="ThmbCol"]//p').map { |parag|
        img     = parag.xpath('.//img').first || next
        url     = URI.join(url, img[:src].strip).to_s
        caption = parag.xpath('./small/text()').text.strip
        {:url => url, :caption => caption}
      }.compact
      return images
    end
=end

    def self.extract_body(src)
      doc = Nokogiri.HTML(src)

      # 全体の不要な要素を削除
      doc.xpath("//comment()").remove
      doc.xpath("//script").remove
      doc.xpath("//noscript").remove
      doc.xpath("//text()").
        select { |node| node.text.strip.empty? }.
        each   { |node| node.remove }

      # 本文のdiv要素を取得
      body = doc.xpath('//*[@id="maincol"]/div[@class="content"]/p[@class="preface"]').first

      # a要素のtarget要素を削除
      body.xpath('.//a').each { |node| node.remove_attribute("target") }
      # img要素のborder属性を削除
      body.xpath('.//img').each { |node| node.remove_attribute("border") }

      # 本文の不要なclass属性を削除
      body.remove_attribute("class")
      # 本文内のp要素のテキストをクリーンアップ
      body.xpath('.//p/text()').each { |node|
        text = node.text.strip
        text.sub!(/^　/, "")
        # for Kindle 3
        text.gsub!(/◇/, "<>") # U+25C7 -> ASCII
        text.gsub!(/─/, "―") # U+2500 -> U+2015
        text.gsub!(/━/, "―") # U+2501 -> U+2015
        text.gsub!(/～/, "〜") # U+FF5E -> U+301C
        node.replace(Nokogiri::XML::Text.new(text, doc))
      }

      return body.to_xml(:indent => 1, :encoding => "UTF-8")
    end
  end
end
