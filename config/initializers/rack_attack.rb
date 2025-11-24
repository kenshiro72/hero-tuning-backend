# frozen_string_literal: true

# Rack::Attack - レート制限とスロットリング設定
# DoS攻撃、ブルートフォース攻撃、過度なAPI使用から保護

class Rack::Attack
  ### 設定 ###

  # Rack::Attackデータストア（Railsキャッシュを使用）
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # セーフリスト（ホワイトリスト）
  # 開発環境ではlocalhostを常に許可
  safelist('allow-localhost') do |req|
    Rails.env.development? && ['127.0.0.1', '::1'].include?(req.ip)
  end

  ### スロットリング（Throttle）###

  # 一般的なAPIリクエストの制限
  # IP単位で1分間に100リクエストまで
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # 最適化エンドポイントの厳しい制限
  # 計算コストが高いため、1分間に10リクエストまで
  throttle('api/optimize', limit: 10, period: 1.minute) do |req|
    req.ip if req.path.include?('/optimize') && req.post?
  end

  # 状態変更リクエスト（POST/PUT/PATCH/DELETE）の制限
  # 1分間に50リクエストまで
  throttle('api/writes', limit: 50, period: 1.minute) do |req|
    if req.path.start_with?('/api/') && %w[POST PUT PATCH DELETE].include?(req.request_method)
      req.ip
    end
  end

  # GETリクエストの緩い制限
  # 1分間に200リクエストまで
  throttle('api/reads', limit: 200, period: 1.minute) do |req|
    if req.path.start_with?('/api/') && req.get?
      req.ip
    end
  end

  ### カスタムスロットリングレスポンス ###

  # レート制限超過時のレスポンス
  self.throttled_responder = lambda do |env|
    retry_after = env['rack.attack.match_data'][:period]
    [
      429, # Too Many Requests
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{ error: 'Rate limit exceeded. Please try again later.', retry_after: retry_after }.to_json]
    ]
  end

  ### ブロックリスト（Blacklist）###

  # 悪意のあるIPアドレスをブロック（必要に応じて追加）
  # blocklist('block-bad-ips') do |req|
  #   # 環境変数からブロックリストを読み込む例
  #   blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',')
  #   blocked_ips.include?(req.ip)
  # end

  ### ロギング ###

  # スロットリングイベントをログに記録
  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _request_id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Throttled: #{req.ip} " \
      "Path: #{req.path} " \
      "Method: #{req.request_method} " \
      "Discriminator: #{payload[:discriminator]} " \
      "Matched: #{payload[:matched]}"
    )
  end

  # ブロックイベントをログに記録
  ActiveSupport::Notifications.subscribe('blocklist.rack_attack') do |_name, _start, _finish, _request_id, payload|
    req = payload[:request]
    Rails.logger.error(
      "[Rack::Attack] Blocked: #{req.ip} " \
      "Path: #{req.path} " \
      "Method: #{req.request_method}"
    )
  end
end
