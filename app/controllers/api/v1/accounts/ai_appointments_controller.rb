class Api::V1::Accounts::AiAppointmentsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_appointment, only: [:show, :update, :destroy]

  def index
    @appointments = Current.account.ai_appointments.includes(:contact, :catalog_item, :assignee)
    @appointments = @appointments.by_status(params[:status]) if params[:status].present?
    @appointments = @appointments.upcoming
    render json: appointments_json(@appointments)
  end

  def show
    render json: appointment_json(@appointment)
  end

  def create
    @appointment = Current.account.ai_appointments.build(appointment_params)
    if @appointment.save
      render json: appointment_json(@appointment), status: :created
    else
      render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @appointment.update(appointment_params)
      render json: appointment_json(@appointment)
    else
      render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.destroy!
    head :ok
  end

  private

  def fetch_appointment
    @appointment = Current.account.ai_appointments.find(params[:id])
  end

  def appointment_params
    params.require(:ai_appointment).permit(:contact_id, :catalog_item_id, :assignee_id, :appointment_date, :start_time, :end_time, :status, :notes)
  end

  def appointment_json(a)
    {
      id: a.id,
      contact: { id: a.contact.id, name: a.contact.name, phone_number: a.contact.phone_number },
      catalog_item: a.catalog_item ? { id: a.catalog_item.id, name: a.catalog_item.name } : nil,
      assignee: a.assignee ? { id: a.assignee.id, name: a.assignee.name } : nil,
      appointment_date: a.appointment_date,
      start_time: a.start_time,
      end_time: a.end_time,
      status: a.status,
      notes: a.notes,
      created_at: a.created_at
    }
  end

  def appointments_json(list)
    list.map { |a| appointment_json(a) }
  end
end
