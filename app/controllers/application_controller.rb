class ApplicationController < ActionController::API
  # 共通のエラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ArgumentError, with: :argument_error

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
end
