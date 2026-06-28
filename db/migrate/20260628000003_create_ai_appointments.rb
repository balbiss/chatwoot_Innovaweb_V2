class CreateAiAppointments < ActiveRecord::Migration[7.0]
  def change
    unless table_exists?(:ai_appointments)
      create_table :ai_appointments do |t|
        t.references :account, null: false, foreign_key: true
        t.references :contact, null: false, foreign_key: true
        t.references :catalog_item, foreign_key: true
        t.bigint :assignee_id
        t.date :appointment_date, null: false
        t.string :start_time, null: false
        t.string :end_time
        t.string :status, default: 'scheduled'
        t.text :notes
        t.timestamps
      end

      add_index :ai_appointments, [:account_id, :appointment_date]
      add_index :ai_appointments, [:account_id, :status]
      add_index :ai_appointments, :assignee_id
    end
  end
end
