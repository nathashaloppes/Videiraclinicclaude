# Itens "extras" que o cliente pode adicionar ao carrinho além do turno.
# Catálogo fixo (não é ActiveRecord). Persistidos no booking_group como JSON.
class Extra
  CATALOG = {
    "filmaker" => { name: "Filmaker", price_cents: 1000 }
  }.freeze

  attr_reader :key, :name, :price_cents

  def initialize(key, name, price_cents)
    @key = key
    @name = name
    @price_cents = price_cents
  end

  def self.all
    CATALOG.map { |key, attrs| new(key, attrs[:name], attrs[:price_cents]) }
  end

  def self.find(key)
    attrs = CATALOG[key.to_s]
    attrs && new(key.to_s, attrs[:name], attrs[:price_cents])
  end

  # session[:cart_extras] => { "filmaker" => 2 }  →  [[Extra, 2], ...]
  def self.from_session(hash)
    Array(hash).filter_map do |key, qty|
      qty = qty.to_i
      next if qty <= 0
      extra = find(key)
      [extra, qty] if extra
    end
  end
end
