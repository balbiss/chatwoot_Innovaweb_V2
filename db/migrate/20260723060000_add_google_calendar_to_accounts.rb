class AddGoogleCalendarToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :google_calendar_refresh_token, :text unless column_exists?(:accounts, :google_calendar_refresh_token)
    add_column :accounts, :google_calendar_id, :string, default: 'primary' unless column_exists?(:accounts, :google_calendar_id)
  end
end
