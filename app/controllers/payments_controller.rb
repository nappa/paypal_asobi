# -*- coding: utf-8 -*-
require 'openssl'

#
# Paypal Form reference:
# https://developer.paypal.com/webapps/developer/docs/classic/paypal-payments-standard/integration-guide/Appx_websitestandard_htmlvariables/
#
# 暗号化方式の説明は、何処にも無い。
# https://www.paypal.com/us/cgi-bin/webscr?cmd=p/xcl/rec/ewp-code
# ↑のコードをRubyで書くよりない……
#


class PaymentsController < ApplicationController
  def start
  end

  def start_encrypted
    content = {
      "charset" => "utf-8",
      "business"  => "sunaoshi@kimaroki.jp",

      # 商品名
      "item_name" => "第十七回文学フリマ出店料 (ブース1つ、追加イスなし)",
      # 通貨 (JPY=日本円)
      "currency_code" => "JPY",
      # 金額
      "amount" => "3500",

      # カスタム変数
      "custom" => "tx-123412341234",

      # アドレスを上書きするか?
      "address_override" => "1",

      # フォームを上書きする内容
      "country" => "JP",
      "first_name" => "野原",
      "last_name" => "しんのすけ",
      "address1" => "ひまわり町",
      "address2" => "1-2-3–123",
      "city" => "春日部市",
      "state" => "埼玉県",
      "zip" => "123-1234",
      "night_phone_a" => "090",
      "night_phone_b" => "1234",
      "night_phone_c" => "5678",
      "email" => "shinchan@kimaroki.jp",
    }
    @encrypted = encrypt_for_paypal(content)
  end

  def finish
  end

  private

  # TODO: パスを environments 毎にわけたい
  PAYPAL_CERT_PEM = File.read("#{Rails.root}/config/paypal_cert_pem.txt")
  APP_CERT_PEM = File.read("#{Rails.root}/config/paypal_my_public_key.pem")
  APP_KEY_PEM  = File.read("#{Rails.root}/config/paypal_my_private_key.pem")

  PAYPAL_CERT  = OpenSSL::X509::Certificate.new(PAYPAL_CERT_PEM)
  APP_CERT     = OpenSSL::X509::Certificate.new(APP_CERT_PEM)
  APP_KEY      = OpenSSL::PKey::RSA.new(APP_KEY_PEM, '')

  def encrypt_for_paypal(values)
    signed = OpenSSL::PKCS7::sign(APP_CERT,
                                  APP_KEY,
                                  values.map { |k, v| "#{k}=#{v}" }.join("\n"),
                                  [],
                                  OpenSSL::PKCS7::BINARY)

    encrypted = OpenSSL::PKCS7::encrypt([PAYPAL_CERT],
                                        signed.to_der,
                                        # TODO: より安全な 'DES-EDE3-CBC', 'AES-256-CBC' も試してみる
                                        OpenSSL::Cipher::new('DES3'),
                                        OpenSSL::PKCS7::BINARY).to_s.gsub("\n", "")
  end
end
