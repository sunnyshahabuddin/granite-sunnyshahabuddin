# frozen_string_literal: true

# Rails.application.routes.draw do
#   # resources :tasks, except: %i[new edit], param: :slug, defaults: { format: "json" }
#   # resources :users, only: :index
#   defaults format: :json do
#     resources :tasks, except: %i[new edit], param: :slug
#     resources :users, only: :index
#   end

#   root "home#index"
#   get "*path", to: "home#index", via: :all

# end

Rails.application.routes.draw do
  constraints(lambda { |req| req.format == :json }) do
    resources :tasks, except: %i[new edit], param: :slug
    resources :users, only: :index
  end

  root "home#index"
  get "*path", to: "home#index", via: :all
end

# Rails.application.routes.draw do
#   resources :tasks, only: %i[index create], param: :slug
# end
