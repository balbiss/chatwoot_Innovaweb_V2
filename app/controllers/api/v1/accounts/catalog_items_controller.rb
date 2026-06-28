class Api::V1::Accounts::CatalogItemsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_catalog_item, only: [:show, :update, :destroy]

  def index
    @items = Current.account.catalog_items.ordered
    @items = @items.by_category(params[:category]) if params[:category].present?
    @items = @items.active if params[:active].present?
    render json: catalog_items_json(@items)
  end

  def show
    render json: catalog_item_json(@item)
  end

  def create
    @item = Current.account.catalog_items.build(catalog_item_params)
    if @item.save
      attach_photos if params[:photos].present?
      render json: catalog_item_json(@item), status: :created
    else
      render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @item.update(catalog_item_params)
      attach_photos if params[:photos].present?
      render json: catalog_item_json(@item)
    else
      render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy!
    head :ok
  end

  private

  def fetch_catalog_item
    @item = Current.account.catalog_items.find(params[:id])
  end

  def catalog_item_params
    params.require(:catalog_item).permit(:name, :description, :price, :category, :duration_minutes, :active, :position)
  end

  def attach_photos
    Array(params[:photos]).each { |photo| @item.photos.attach(photo) }
  end

  def catalog_item_json(item)
    {
      id: item.id,
      name: item.name,
      description: item.description,
      price: item.price,
      price_formatted: item.price_formatted,
      category: item.category,
      duration_minutes: item.duration_minutes,
      active: item.active,
      position: item.position,
      photos: item.photos.map { |p| { id: p.id, url: url_for(p) } }
    }
  end

  def catalog_items_json(items)
    items.map { |i| catalog_item_json(i) }
  end
end
