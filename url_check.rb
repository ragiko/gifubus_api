# coding: utf-8 

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'date'
require 'csv'


url = "http://navi.gifubus.co.jp/Frm_0000.aspx"
doc = Nokogiri::HTML(open(URI.encode(url)))
gifubus_url = doc.css("form#aspnetForm").attribute("action").value;

access_id = gifubus_url.match(/ge=(.*?)&/)[1]
day_str = Date.today.to_s

CSV.open("logs/data.csv","a") do |csv|
  csv << [day_str, access_id]
end

# # ファイルの末尾のidを取得
# table = CSV.open("test.csv").read
# recent_id = table.last[1]
