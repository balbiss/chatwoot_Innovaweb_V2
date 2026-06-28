class CatalogItem < ApplicationRecord
  belongs_to :account
  has_many_attached :photos

  validates :name, presence: true
  validates :account_id, presence: true

  scope :active, -> { where(active: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :ordered, -> { order(position: :asc, name: :asc) }

  def price_formatted
    return nil unless price
    "R$ #{format('%.2f', price).gsub('.', ',')}"
  end
end
