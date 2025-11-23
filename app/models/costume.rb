class Costume < ApplicationRecord
  belongs_to :character
  has_many :slots

  # 標準シリーズの順序定義
  STANDARD_SERIES_ORDER = {
    nil => 0,              # デフォルト（〈〉なし）
    'ヴィランライク' => 1, # ヒーローキャラの場合
    'ヒーローライク' => 1, # ヴィランキャラの場合
    'ヒート' => 2,
    'コンバット' => 3,
    'ファンシー' => 4,
    'デンジャラス' => 5
  }.freeze

  # スーパースター・アイドル系の順序
  IDOL_SERIES_ORDER = {
    nil => 0,           # デフォルト
    'ビオラ' => 1,
    'スカーレット' => 2,
    'アプリコット' => 3,
    'ミモザ' => 4,
    'ラナンキュラス' => 5
  }.freeze

  # ボランティア活動系の順序
  VOLUNTEER_SERIES_ORDER = {
    nil => 0,          # デフォルト
    'ネイビー' => 1,
    'オレンジ' => 2,
    'ブラック' => 3,
    'ピンク' => 4,
    'スカイブルー' => 5
  }.freeze

  # ベース名を抽出（〈〉の前の部分）
  def base_name
    name.split('〈')[0]
  end

  # シリーズ名を抽出（〈〉内の文字列、なければnil）
  def series
    match = name.match(/〈(.+?)〉/)
    match ? match[1] : nil
  end

  # このコスチュームのベース名に応じた適切なシリーズ順序マップを取得
  def series_order_map
    case base_name
    when 'スーパースター・アイドル'
      IDOL_SERIES_ORDER
    when 'ボランティア活動'
      VOLUNTEER_SERIES_ORDER
    else
      STANDARD_SERIES_ORDER
    end
  end

  # シリーズのソート順を決定
  def series_order
    series_name = series
    order_map = series_order_map

    # マップに定義されている場合はその順序を返す
    return order_map[series_name] if order_map.key?(series_name)

    # 標準シリーズの場合、ーライク系の特殊処理
    if order_map == STANDARD_SERIES_ORDER
      character_class = character.character_class
      if series_name == 'ヴィランライク' && character_class == 'HERO'
        return 1
      elsif series_name == 'ヒーローライク' && character_class == 'VILLAIN'
        return 1
      end
    end

    # その他の未定義シリーズは最後に（アルファベット順）
    999
  end

  # コスチュームをシリーズ順にソート
  # IMPORTANT: このスコープはRuby側でソートを行うため、:characterアソシエーションを
  # eager loadする必要があります。includes(:character)を必ず使用してください。
  # series_orderメソッドがcharacter.character_classにアクセスするため、
  # eager loadしないとN+1クエリが発生します。
  scope :ordered_by_series, -> {
    includes(:character).sort_by { |costume| [costume.series_order, costume.id] }
  }
end
