module Grapes
    class API < Grape::API
        format :json
        prefix :api
        version "v1", :path

        mount Grapes::V1::MemoAPI
        mount Grapes::V1::UserAPI
        # mount Grapes::V1::UserSettingApi
    end
end