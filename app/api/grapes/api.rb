module Grapes
    class API < Grape::API
        format :json
        prefix :api
        version "v1", :path

        mount Grapes::V1::MemoAPI
        mount Grapes::V1::UserSettingAPI
        mount Grapes::V1::UserAPI
    end
end