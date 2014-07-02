require 'rubygems'
require 'sinatra'
require "json"
require 'active_support/core_ext'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'pp'

get '/error' do
  "bad query"
end

get '/' do

	date = params['data']
  time = params['time']
  start_arrive = params['start_arrive']
  start_name = params['start_name']
  arrive_name = params['arrive_name']

  # エラー処理
  if (date.blank? || time.blank? || start_arrive.blank? || start_name.blank? || arrive_name.blank?)
  	redirect 'error'
  end

	# クエリ
	q = {
		date: date, 				# 日付
		time: time, 								# 時間
		start_arrive: start_arrive, 						# 出発: 1, 到着: 0
		start_name: start_name, 			# 出発駅名
		arrive_name: arrive_name, 		# 到着駅名
	}

	url = <<"EOS"
http://navi.gifubus.co.jp/Frm_0160.aspx\
?ge=t3_1kv_4nz_5fr_67j\
&id=1qc346\
&ia=1qc31f\
&d=1\
&t=#{q[:time]}\
&a=#{q[:start_arrive]}\
&tt=1\
&cm=1\
&ds=#{q[:start_name]}\
&as=#{q[:arrive_name]}\
&inpym=#{q[:date].split('/')[0]+'/'+q[:date].split('/')[1]}\
&inpymd=#{q[:date]}\
&inpt=#{q[:time]}\
&inpa=#{q[:start_arrive]}
EOS

	doc = Nokogiri::HTML(open(URI.encode(url)))

	routes = []

	for i in 1..3
		doc.xpath("//div[@id='ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_UpdtPnl_Route']").each do |route|

			# 一番上の情報
			time 			= /：(.*)$/.match(route.xpath(".//span[@id='ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteInfo1_Lbl_Information1']").text)[1]
			price 		= /：(.*)$/.match(route.xpath(".//span[@id='ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteInfo1_Lbl_Information2']").text)[1]
			transfer	= /：(.*)$/.match(route.xpath(".//span[@id='ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteInfo1_Lbl_Information3']").text)[1]

			# 中間の詳細情報
			info = []

			# 繰り返し回数の決定
			transfer_num = /^(.*)回/.match(transfer)[1].to_i
			label_repeat = []

			if transfer_num == 0
				label_repeat = ['Fal']
			else
				label_repeat = ['Fal', 'Ent']
			end

			# 乗り換え時に１つ目:Fal 2つ目Entとなっている
			for label in label_repeat
				start_name = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_OnStationname").text
				if ((n = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_OnStationPole").text) != '　')
					start_name += n
				end
				start_time = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_DepartureTime").text

				between_minutes = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_RequireTime").text
				fare = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_Fare").text

				arrive_name = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_OffStationName").text
				if ((n = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_OffStationPole").text) != '　')
					arrive_name += n
				end
				arrive_time = route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_ArrivalTime").text

				# 乗り換えの詳細
				details = []

				details << route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_RosenName").text
				details << route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_Ikisaki").text
				details << route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_CompanyName").text
				details << route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_KeitouNumber").text
				details << route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_RosenName").text
				details << route.css("#ctl00_ContentPlaceHolder1_Usc_RouteG#{i}_Usc_RouteDetailInfo#{label}_Lbl_KeitouInformation").text

				info.push ({
					start_name: start_name,							# 出発駅名
					start_time: start_time,							# 出発時刻
					details: details,  									# 詳細
					between_minutes: between_minutes, 	# 乗車時間
					fare: fare,													# 料金
					arrive_name: arrive_name,						# 到着駅名
					arrive_time: arrive_time 						# 到着時刻
				})
			end

			routes.push({time: time, price: price, transfer: transfer, info: info})
		end
	end

  content_type :json
	routes.to_json
end
