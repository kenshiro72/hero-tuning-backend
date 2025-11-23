class ApplicationController < ActionController::API
  # CSRF保護を有効化（将来の認証実装に備える）
  include ActionController::RequestForgeryProtection

  # 状態変更リクエストの前にCSRF検証を実行
  # GETとHEADは除外（読み取り専用のため）
  before_action :verify_csrf_protection, if: :state_changing_request?

  # 共通のエラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ArgumentError, with: :argument_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_authenticity_token

  private

  # IDパラメータのバリデーション（SQLインジェクション対策）
  def validate_id_parameter(id_param)
    # IDが数値文字列であることを検証
    unless id_param.to_s =~ /\A\d+\z/
      log_suspicious_request("Invalid ID format", id_param)
      raise ArgumentError, "Invalid ID format"
    end

    id_value = id_param.to_i

    # IDが正の整数であることを検証
    unless id_value.positive?
      log_suspicious_request("Non-positive ID", id_param)
      raise ArgumentError, "Invalid ID value"
    end

    id_value
  end

  # 不審なリクエストをログに記録
  def log_suspicious_request(reason, suspicious_value)
    Rails.logger.warn do
      "[SECURITY] #{reason} | " \
      "IP: #{request.remote_ip} | " \
      "Path: #{request.fullpath} | " \
      "Value: #{suspicious_value.to_s.truncate(100)} | " \
      "User-Agent: #{request.user_agent}"
    end
  end

  # エラーハンドラー - 本番環境では詳細を隠す
  def record_not_found(exception)
    # 本番環境では詳細なエラーメッセージを隠す
    if Rails.env.production?
      Rails.logger.error "[RecordNotFound] #{exception.message}"
      render json: { error: "The requested resource was not found" }, status: :not_found
    else
      render json: { error: "Record not found: #{exception.message}" }, status: :not_found
    end
  end

  def parameter_missing(exception)
    log_suspicious_request("Missing parameter", exception.param)

    if Rails.env.production?
      Rails.logger.error "[ParameterMissing] #{exception.param}"
      render json: { error: "Required parameter is missing" }, status: :bad_request
    else
      render json: { error: "Missing parameter: #{exception.param}" }, status: :bad_request
    end
  end

  def record_invalid(exception)
    # バリデーションエラーは開発に役立つため、詳細を返す
    # ただし、本番環境ではログに記録
    if Rails.env.production?
      Rails.logger.error "[RecordInvalid] #{exception.record.errors.full_messages.join(', ')}"
    end

    render json: {
      error: "Validation failed",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def argument_error(exception)
    # 不正な引数（無効なID形式など）
    if Rails.env.production?
      Rails.logger.error "[ArgumentError] #{exception.message}"
      render json: { error: "Invalid request parameters" }, status: :bad_request
    else
      render json: { error: exception.message }, status: :bad_request
    end
  end

  def invalid_authenticity_token(exception)
    log_suspicious_request("CSRF token verification failed", request.headers["X-CSRF-Token"] || "none")

    if Rails.env.production?
      Rails.logger.error "[InvalidAuthenticityToken] #{exception.message}"
      render json: { error: "Request verification failed" }, status: :forbidden
    else
      render json: { error: "CSRF token verification failed: #{exception.message}" }, status: :forbidden
    end
  end

  # === CSRF保護メソッド ===

  # 状態変更リクエストかどうかを判定
  def state_changing_request?
    !request.get? && !request.head?
  end

  # リクエストが検証済みかどうかを判定
  def verified_request?
    # 複数の検証方法をサポート
    valid_origin_header? || valid_custom_header? || valid_csrf_token?
  end

  # CSRF保護の検証
  def verify_csrf_protection
    return if verified_request?

    # 検証失敗 - ログに記録して拒否
    log_suspicious_request(
      "CSRF protection failed",
      "Origin: #{request.headers['Origin']}, Referer: #{request.headers['Referer']}"
    )

    render json: {
      error: Rails.env.production? ? "Request verification failed" : "CSRF protection failed"
    }, status: :forbidden
  end

  # Origin/Refererヘッダーの検証
  def valid_origin_header?
    origin = request.headers["Origin"] || extract_origin_from_referer
    return false unless origin

    allowed_origins = [
      ENV.fetch("FRONTEND_URL", "http://localhost:3000"),
      # 開発環境用の追加オリジン
      ("http://localhost:3001" if Rails.env.development?)
    ].compact

    allowed_origins.any? { |allowed| origin.start_with?(allowed) }
  end

  # Refererからオリジンを抽出
  def extract_origin_from_referer
    referer = request.headers["Referer"]
    return nil unless referer

    uri = URI.parse(referer)
    "#{uri.scheme}://#{uri.host}:#{uri.port}"
  rescue URI::InvalidURIError
    nil
  end

  # カスタムヘッダーの検証（AJAX専用）
  def valid_custom_header?
    # X-Requested-Withヘッダーの存在を確認
    # ブラウザの同一生成元ポリシーにより、他のドメインから設定できない
    request.headers["X-Requested-With"] == "XMLHttpRequest"
  end

  # CSRFトークンの検証（将来の認証実装用）
  def valid_csrf_token?
    # CSRFトークンがある場合は検証
    return false unless request.headers["X-CSRF-Token"].present?

    # Rails標準のトークン検証
    verified_request = form_authenticity_token == request.headers["X-CSRF-Token"]
    verified_request
  rescue ActionController::InvalidAuthenticityToken
    false
  end
end
