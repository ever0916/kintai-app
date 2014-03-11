json.array!(@kintais) do |kintai|
  json.extract! kintai, :id, :user_id, :t_syukkin, :t_taikin
  json.url kintai_url(kintai, format: :json)
end
