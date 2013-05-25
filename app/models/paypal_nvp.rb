# -*- coding: utf-8 -*-

require 'cgi'

# PayPal Name-Value Pair
class PaypalNvp < Hash
  def self.parse(data)
    ary = data.split("\n").map { |line|
      k, v = line.split('=')
      [k, v]
    }.flatten(1)

    obj = Hash[*ary]

    if obj["charset"]
      encoding = obj["charset"]

      self[*obj.map { |k, v|
             [
               decode(k, encoding),
               decode(v, encoding)
             ]
      }.flatten(1)]
    else
      self.new(obj)
    end
  end

  def self.decode(string, encoding)
    if encoding == 'Shift_JIS'
      encoding = 'Windows-31J'
    end

    if string.nil? || string.empty?
      # 変換不要
      string
    elsif encoding.upcase == 'UTF-8'
      CGI.unescape(string)
    else
      CGI.unescape(string).force_encoding(encoding).encode('UTF-8', {:invalid => :replace,
                                                             :undef   => :replace,
                                                             :replace => "?",
                                                             :universal_newline => true})
    end
  end
end

if __FILE__ == $0
  require 'pp'

  str = <<END
SUCCESS
a=b
c=d
END

  nvp = PaypalNvp.parse(str)
  pp nvp

  str = "SUCCESS\nmc_gross=3500\ninvoice=3a116c3d85e84133b2f014a12fa9bd\nprotection_eligibility=Ineligible\naddress_status=unconfirmed\npayer_id=GNYQXJEQ77FKY\ntax=0\naddress_street=%82%D0%82%DC%82%ED%82%E8%92%AC%0D%0A1-2-3%FC%FC123\npayment_date=16%3A38%3A03+May+24%2C+2013+PDT\npayment_status=Completed\ncharset=Shift_JIS\naddress_zip=123-1234\nfirst_name=Kenji\nmc_fee=166\naddress_country_code=JP\naddress_name=%96%EC%8C%B4+%82%B5%82%F1%82%CC%82%B7%82%AF\ncustom=tx-123412341234\npayer_status=unverified\nbusiness=suoaoshi%40kimaroki.jp\naddress_country=Japan\naddress_city=%8Ft%93%FA%95%94%8Es\nquantity=1\npayer_email=matasaburou%40kimaroki.jp\ntxn_id=5RT094219P2792544\npayment_type=instant\nlast_name=Miyazawa\naddress_state=%8D%E9%8B%CA%8C%A7\nreceiver_email=suoaoshi%40kimaroki.jp\npayment_fee=\nreceiver_id=AVZU7JG6Q2JTC\ntxn_type=web_accept\nitem_name=%91%E6%8F%5C%8E%B5%89%F1%95%B6%8Aw%83t%83%8A%83%7D%8Fo%93X%97%BF+%28%83u%81%5B%83X1%82%C2%81A%92%C7%89%C1%83C%83X%82%C8%82%B5%29\nmc_currency=JPY\nitem_number=\nresidence_country=JP\nhandling_amount=0\ntransaction_subject=tx-123412341234\npayment_gross=\nshipping=0\n"
  nvp = PaypalNvp.parse(str)
  pp nvp
end
