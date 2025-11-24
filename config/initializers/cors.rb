# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # 環境変数を使用してオリジンを設定（セキュリティ向上）
    # 複数のオリジンをカンマ区切りで指定可能
    # 例: FRONTEND_URL=https://app.example.com,https://staging.example.com
    allowed_origins = ENV.fetch("FRONTEND_URL", "http://localhost:3000").split(',').map(&:strip)

    # 開発環境では localhost:3001 も追加で許可
    allowed_origins << "http://localhost:3001" if Rails.env.development?

    origins allowed_origins

    resource "/api/v1/*",
      # 必要なヘッダーのみ許可
      headers: %w[Content-Type Accept Authorization],
      # 実際に使用されているHTTPメソッドのみ許可（セキュリティ向上）
      # 現在: GET（読み取り）、POST（状態変更）のみ使用
      # 将来的に必要になった場合: :put, :patch, :delete を追加
      methods: [ :get, :post, :options, :head ],
      # クレデンシャル（Cookie）を含むリクエストを許可する場合は true
      # 現在は認証なしのため false
      credentials: false,
      # プリフライトリクエストのキャッシュ時間（秒）
      max_age: 600
  end
end
