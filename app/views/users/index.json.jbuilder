json.array!(@users) do |user|
  json.extract! user, :id, :name, :f_state
  json.url user_url(user, format: :json)
end
