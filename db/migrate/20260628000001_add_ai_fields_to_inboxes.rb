class AddAiFieldsToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :ai_enabled, :boolean, default: false unless column_exists?(:inboxes, :ai_enabled)
    add_column :inboxes, :ai_name, :string unless column_exists?(:inboxes, :ai_name)
    add_column :inboxes, :ai_temperature, :float, default: 0.7 unless column_exists?(:inboxes, :ai_temperature)
    add_column :inboxes, :ai_greeting_use_name, :boolean, default: true unless column_exists?(:inboxes, :ai_greeting_use_name)
    add_column :inboxes, :ai_greeting_use_time, :boolean, default: true unless column_exists?(:inboxes, :ai_greeting_use_time)
    add_column :inboxes, :ai_first_message, :text unless column_exists?(:inboxes, :ai_first_message)
    add_column :inboxes, :ai_return_message, :text unless column_exists?(:inboxes, :ai_return_message)
    add_column :inboxes, :ai_business_hours, :jsonb, default: {} unless column_exists?(:inboxes, :ai_business_hours)
    add_column :inboxes, :ai_out_of_hours_message, :text unless column_exists?(:inboxes, :ai_out_of_hours_message)
    add_column :inboxes, :ai_out_of_hours_action, :string, default: 'register_and_notify' unless column_exists?(:inboxes, :ai_out_of_hours_action)
    add_column :inboxes, :ai_transfer_team_id, :bigint unless column_exists?(:inboxes, :ai_transfer_team_id)
    add_column :inboxes, :ai_followup_enabled, :boolean, default: false unless column_exists?(:inboxes, :ai_followup_enabled)
    add_column :inboxes, :ai_followup_wait_minutes, :integer, default: 120 unless column_exists?(:inboxes, :ai_followup_wait_minutes)
    add_column :inboxes, :ai_followup_max_attempts, :integer, default: 3 unless column_exists?(:inboxes, :ai_followup_max_attempts)
    add_column :inboxes, :ai_followup_closing_message, :text unless column_exists?(:inboxes, :ai_followup_closing_message)
  end
end
