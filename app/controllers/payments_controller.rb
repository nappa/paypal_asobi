# -*- coding: utf-8 -*-
require 'openssl'
require 'pp'
require 'awesome_print'

#
# PayPal PDT/IPN の実験的実装。
#
# Reference:
#  * Paypal Form reference:
#    https://developer.paypal.com/webapps/developer/docs/classic/paypal-payments-standard/integration-guide/Appx_websitestandard_htmlvariables/
#
#
#  * PayPal IPN and PDT Variables:
#    https://cms.paypal.com/jp/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_html_IPNandPDTVariables
#  * PayPal 暗号化まわりのサンプルコード:
#    https://www.paypal.com/us/cgi-bin/webscr?cmd=p/xcl/rec/ewp-code
#
#

class PaymentsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [ :ipn ]

  def start
  end

  def start_encrypted
    @content = {
      'random'   => SecureRandom.hex(24), # 転ばぬ先の何とやら...
      'cert_id'  => PaypalConfig[:paypal_cert_id], # 証明書ID (PayPalのサイトに出る)
      'business' => PaypalConfig[:paypal_email],   # ビジネスアカウント(メールアドレス)

      'cmd' => '_xclick',
      'charset' => 'utf-8',

      # 商品名
      'item_name' => '第十七回文学フリマ出店料 (ブース1つ、追加イスなし)',
      # 通貨 (JPY=日本円)
      'currency_code' => 'JPY',
      # 金額
      'amount' => '3500',

      # パススルー変数
      ### 請求書ID(128バイトまで)。
      ### PayPal 内で Unique でなければならない
      'invoice' => SecureRandom.hex(15),
      ### 使徒不定(256バイトまで)
      'custom' => 'tx-123412341234',

      # 決済完了時のリンク先URL
      'return' => url_for(:action => :finish),
      # 決済キャンセル時のリダイレクト先URL
      'cancel_return' => url_for(:action => :cancel),

      # アドレスを強制的に上書きするか? (1にすると不具合が起きそうなのでやめとく)
      'address_override' => '0',

      # 登録フォーム類を強制的に日本語にする
      'lc' => 'jp_JP',

      # 非PayPal会員向けにフォームにプレフィルする内容を設定
      'country'    => 'JP',
      'first_name' => '野原',
      'last_name'  => 'しんのすけ',
      'address1'   => 'ひまわり町',
      'address2'   => '1-2-3–123',
      'city'       => '春日部市',
      'state'      => '埼玉県',
      'zip'        => '123-1234', #仕様上ハイフンはダメと書いてあるが、ハイフンがないと逆に不具合が起きてしまう
      'night_phone_a' => '+81', # U.S. 以外の場合は国番号
      'night_phone_b' => '0312345678',
      'email'      => 'shinchan@kimaroki.jp',
    }
    @encrypted = encrypt_for_paypal(@content)
  end

  # POST /payments/finish
  # (PayPal 側の画面を経て決済を完了した場合にここに POST されてくる)
  def finish
    logger.info params

    # こんな感じでPOSTされてくる
    "http://fierce-scrubland-4220.herokuapp.com/payments/finish?tx=5RT094219P2792544&st=Completed&amt=3500&cc=JPY&cm=tx%252d123412341234&item_number="

    if params[:tx].blank?
      # TODO 適切なエラー画面に飛ばす
      raise "PayPal BUG? - tx is blank!"
    end

    if params[:st] != 'Completed'
      raise "PayPal BUG? - params[:st](#{params[:st]}) != 'Completed'"
      # TODO エラー処理
    else
      # PayPal に対してクエリを送信する
      nvp = pdt(params[:tx))

      if nvp.has_key?('SUCCESS')

        if nvp['txn_id'] != params['txn_id']
          raise "PayPal BUG? - nvp['txn_id'](#{nvp['txn_id']}) != params['tx'](#{params['tx']})"
        end

        ## check that txn_id has not been previously processed
        #
        # if nvp['txn_id'] != xxx...
        #   raise
        # end

        ## check that receiver_email is your Primary PayPal email
        if nvp['receiver_email'] != PaypalConfig[:paypal_email]
          # TODO エラー画面を出す
        end

        ## invoice で対応する payment を探す。なけれぱエラー
        # payment = Payment.find(:invoice, nvp['invoice'])
        # if payment.nil?
        #   # エラー
        # end
        #
        # TODO 数量と金額を確認。
        # TODO トランザクション内で完了ステータスに変更
        # TODO 完了済でない場合、メールを出す
        # TODO 完了しました画面を出す
      elsif nvp.has_key?('FAIL')
        # TODO エラー画面を出す
        # (しばらく経ってからお待ちください、みたいな感じ?)
        # どんなケースにここに飛んでくるかがわからないので、要調査
      else
        # TODO エラー処理
      end
    end

  end

  # GET /payments/cancel
  # (PayPal 画面中でキャンセルを指示された場合にここにリダイレクトされてくる)
  def cancel
    logger.info params

    # invoice と custom に対応する payment を探す。
    # それが処理中のステータスであれば
    #   * invoice に対応する payment をキャンセル済ステータスへ変更する
    #   * 「キャンセルしました、再度決済するには〜」画面を出す
    # それが決済済のステータスであれば
    #   * 「決済済です」画面を出す
    # それがキャンセル済のステータスであれば
    #   * 「キャンセル済です、再度決済するには〜」画面を出す
    #

  end

  # GET /payments/ipn
  # POST /payments/ipn
  # PayPal IPN Endpoint
  def ipn
    # CSRF Token は切ってある (csrf-token が付与できないため)
    logger.info params
  end

  private

  # PDT を実行して PayPal からデータを取得します
  def pdt(tx)
    url = URI.parse(PaypalConfig[:paypal_url])

    conn = Faraday.new(:url => url.scheme + '://' + url.host) do |builder|
    #  builder.request  :retry, { limit: 5, interval: 0.2 }
      builder.response :logger
      builder.response :raise_error
      builder.adapter  :net_http
    end

    form = URI.encode_www_form({
                                 :submit => 'PDT',
                                 :charset => 'utf-8',
                                 :cmd    => '_notify-synch',
                                 :tx     => tx,
                                 :at     => PaypalConfig[:paypal_pdt_token],
                               })

    pdt = conn.post do |req|
      req.url url.path
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8'

      req.body = form
    end

    response = pdt.env[:body]
    return PaypalNvp.parse(response)
  end

  # TODO: パスを environments 毎にわけたい
  PAYPAL_CERT_PEM = File.read(PaypalConfig[:path][:paypal_cert])
  APP_CERT_PEM    = File.read(PaypalConfig[:path][:merchant_cert])
  APP_KEY_PEM     = File.read(PaypalConfig[:path][:merchant_pubkey])

  # PayPal の公開鍵と証明書 (あらかじめダウンロードしておく)
  PAYPAL_CERT  = OpenSSL::X509::Certificate.new(PAYPAL_CERT_PEM)
  # マーチャントの公開鍵と証明書 (PayPal にあらかじめ登録しておく)
  APP_CERT     = OpenSSL::X509::Certificate.new(APP_CERT_PEM)
  # マーチャントの秘密鍵 (絶対に隠すこと)
  APP_KEY      = OpenSSL::PKey::RSA.new(APP_KEY_PEM, '')

  # 署名時のオプション
  SIGN_OPTS = (OpenSSL::PKCS7::BINARY  |  # バイナリを送る
               OpenSSL::PKCS7::NOCERTS |  # 証明書を送信しない (PayPal側に証明書は保存されている)
               OpenSSL::PKCS7::NOSMIMECAP) # S/MIME Capability を送らない (送っても使わないし)

  # 利用する暗号アルゴリズム (サンプルでは DES-EDE3-CBC)
  CIPHER = 'AES-256-CBC'
  def encrypt_for_paypal(values)
    # 参考: http://railscasts.com/episodes/143-paypal-security?view=asciicast
    content = values.map { |k, v| "#{k}=#{v}" }.join("\n")

    # 署名
    signed = OpenSSL::PKCS7::sign(APP_CERT,
                                  APP_KEY,
                                  content,
                                  [],
                                  SIGN_OPTS)

    # 暗号化
    encrypted = OpenSSL::PKCS7::encrypt([PAYPAL_CERT],
                                        signed.to_der,
                                        # サンプルでは DES-EDE3-CBC だが
                                        # AES-256-CBC のほうが良いに決まってる
                                        OpenSSL::Cipher::new(CIPHER),
                                        OpenSSL::PKCS7::BINARY).to_s.gsub("\n", "")

    encrypted
  end


  # invoice を生成する
  def generate_invoice(length=128)
    SecureRandom.hex(length)
  end
end
