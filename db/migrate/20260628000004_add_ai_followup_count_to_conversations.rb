class AddAiFollowupCountToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :ai_followup_count, :integer, default: 0
  end
end
