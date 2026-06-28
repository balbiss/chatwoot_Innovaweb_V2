class AddAiPromptToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :ai_prompt, :text unless column_exists?(:inboxes, :ai_prompt)
  end
end
