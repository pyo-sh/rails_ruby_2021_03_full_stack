module Grapes 
    module V1
        class UserSettingAPI < Grapes::API
            # 말 안해도 알아야 하는 것
            helpers AuthHelpers

            # /user_setting/
            resource :user_setting do
                # /user_setting/ , GET
                # 서버에 User 의 setting 을 저장하는 구조
                get do
                    authenticate!
                    
                    user_setting = UserSetting.where(user_id: current_user.id).last
                    if user_setting
                        return {
                            success: true,
                            user_setting: user_setting,
                        }
                    else
                        return {
                            success: false,
                            message: "No Settings Available"
                        }
                    end
                end
    
                # /user_setting/update , POST
                # user_setting 의 update 이지만 여기엔 create 도 포함한다.
                params do
                    optional :lang, type: String
                    # ex) en, kor, jap, chi.. 
                    optional :is_reminder_on, type: Boolean
                    optional :is_public, type: Boolean 
                    optional :alarm_time_int, type: Integer
                end
                post :update do
                    authenticate!
                    user_setting = UserSetting.where(user_id: current_user.id).last

                    # user_setting 이 있을 떄 이를 수정할 수 있어야 한다
                    if user_setting
                        # Params 에 대해서 검사... 들어온 것들만 적용하기 위함
                        if params[:lang] != nil
                            user_setting.lang = params[:lang]
                        end

                        if params[:is_reminder_on] != nil
                        user_setting.is_reminder_on = params[:is_reminder_on]
                        end

                        if params[:is_public] != nil 
                        user_setting.is_public = params[:is_public]
                        end

                        if params[:alarm_time_int] != nil
                        user_setting.alarm_time_int = params[:alarm_time_int]
                        end
                        
                        begin
                            user_setting.save!
                        rescue => e
                            return {
                                success: false,
                                message: e.message.to_s
                            }
                        end

                        return {
                            success: true,
                            message: "Modified",
                        }
                    end
                    # 만들어져 있지 않으면 만들면 되는 것이야
                    begin
                        params[:user_id] = current_user.id
                        user_setting = UserSetting.create!(params)
                            return {
                                success: true 
                            }
                    rescue => e
                        return {
                            success: false,
                            message: e.message.to_s
                        }
                    end
                end
            end
        end
    end
end