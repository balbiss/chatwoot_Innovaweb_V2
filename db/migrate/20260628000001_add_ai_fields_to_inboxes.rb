class AddAiFieldsToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :ai_enabled, :boolean, default: false
    add_column :inboxes, :ai_name, :string
    add_column :inboxes, :ai_temperature, :float, default: 0.7
    add_column :inboxes, :ai_greeting_use_name, :boolean, default: true
    add_column :inboxes, :ai_greeting_use_time, :boolean, default: true
    add_column :inboxes, :ai_first_message, :text
    add_column :inboxes, :ai_return_message, :text
    add_column :inboxes, :ai_business_hours, :jsonb, default: {}
    add_column :inboxes, :ai_out_of_hours_message, :text
    add_column :inboxes, :ai_out_of_hours_action, :string, default: 'register_and_notify'
    add_column :inboxes, :ai_transfer_team_id, :bigint
    add_column :inboxes, :ai_followup_enabled, :boolean, default: false
    add_column :inboxes, :ai_followup_wait_minutes, :integer, default: 120
    add_column :inboxes, :ai_followup_max_attempts, :integer, default: 3
    add_column :inboxes, :ai_followup_closing_message, :text
  end
end
