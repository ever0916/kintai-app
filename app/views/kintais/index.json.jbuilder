json.array!(@kintais) do |kintai|
  json.extract! kintai, :id, :user_id, :f_kintai, :t_kintai
  json.url kintai_url(kintai, format: :json)
end
