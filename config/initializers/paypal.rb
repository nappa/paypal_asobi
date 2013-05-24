
PaypalConfig = (
  case Rails.env
  when 'development'
    {
      paypal_url:       'https://www.sandbox.paypal.com/cgi-bin/webscr',
      paypal_email:     'suoaoshi@kimaroki.jp',
      paypal_cert_id:   'YYFQ434FHXAF6',
      paypal_pdt_token: 'Y3dcovaqgV_kjJV7I-rCjQlPETNfK66a8kLcvMW7AhqGTmoa_D0pMGEFQNe',
      path: {
        paypal_cert:     "#{Rails.root}/config/paypal_cert_pem.txt",
        merchant_cert:   "#{Rails.root}/config/paypal_my_public_key.pem",
        merchant_pubkey: "#{Rails.root}/config/paypal_my_private_key.pem",
      },
    }
  when 'test'
    # TODO
    raise 'fill here'
  when 'production'
    {
      paypal_url:       'https://www.sandbox.paypal.com/cgi-bin/webscr',
      paypal_email:     'suoaoshi@kimaroki.jp',
      paypal_cert_id:   'YYFQ434FHXAF6',
      paypal_pdt_token: 'Y3dcovaqgV_kjJV7I-rCjQlPETNfK66a8kLcvMW7AhqGTmoa_D0pMGEFQNe',
      path: {
        paypal_cert:     "#{Rails.root}/config/paypal_cert_pem.txt",
        merchant_cert:   "#{Rails.root}/config/paypal_my_public_key.pem",
        merchant_pubkey: "#{Rails.root}/config/paypal_my_private_key.pem",
      },
    }
  end
)
