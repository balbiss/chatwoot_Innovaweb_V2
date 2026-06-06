class AddAiPromptToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :ai_prompt, :text
  end
end
