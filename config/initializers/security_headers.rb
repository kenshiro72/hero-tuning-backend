# セキュリティヘッダーを設定してアプリケーションを保護

Rails.application.config.action_dispatch.default_headers.merge!(
  # クリックジャッキング対策: iframeでの表示を禁止
  "X-Frame-Options" => "DENY",

  # MIMEタイプスニッフィング対策
  "X-Content-Type-Options" => "nosniff",

  # XSS保護を有効化（レガシーブラウザ向け）
  "X-XSS-Protection" => "1; mode=block",

  # Referrer Policy: リファラー情報の送信を制限
  "Referrer-Policy" => "strict-origin-when-cross-origin",

  # Permissions Policy: ブラウザ機能へのアクセスを制限
  "Permissions-Policy" => "geolocation=(), microphone=(), camera=()"
)

# 本番環境でのみHTTPS強制（HSTS）
if Rails.env.production?
  Rails.application.config.action_dispatch.default_headers.merge!(
    # 1年間HTTPS接続を強制
    "Strict-Transport-Security" => "max-age=31536000; includeSubDomains"
  )
end
