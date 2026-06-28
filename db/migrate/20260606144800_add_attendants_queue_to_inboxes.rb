class AddAttendantsQueueToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :attendants_queue, :jsonb, default: [] unless column_exists?(:inboxes, :attendants_queue)
  end
end
