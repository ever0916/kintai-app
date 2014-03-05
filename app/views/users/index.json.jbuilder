json.array!(@users) do |user|
  json.extract! user, :id, :name, :mail
  json.url user_url(user, format: :json)
end
