class AiAppointment < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :catalog_item, optional: true
  belongs_to :assignee, class_name: 'User', foreign_key: :assignee_id, optional: true

  STATUSES = %w[scheduled confirmed cancelled completed no_show].freeze

  validates :appointment_date, presence: true
  validates :start_time, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :upcoming, -> { where('appointment_date >= ?', Date.today).order(appointment_date: :asc, start_time: :asc) }
  scope :by_status, ->(s) { where(status: s) }
end
