class CreateCatalogItems < ActiveRecord::Migration[7.0]
  def change
    create_table :catalog_items do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.string :category
      t.integer :duration_minutes
      t.boolean :active, default: true
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :catalog_items, [:account_id, :active]
    add_index :catalog_items, [:account_id, :category]
  end
end
