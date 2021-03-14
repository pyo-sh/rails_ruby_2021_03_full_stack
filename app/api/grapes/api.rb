module Grapes
    class API < Grape::API
        format :json
        prefix :api
        version "v1", :path

        mount Grapes::V1::MemoAPI
        # mount Grapes::V1::UserSettingApi
        # mount Grapes::V1::UserApi
    end
end