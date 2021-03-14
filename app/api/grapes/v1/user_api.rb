module Grapes
    module V1
        class UserAPI < Grapes::API
            # v1.rb 의 AuthHelpers 역할 -> jwt
            helpers AuthHelpers

            # /user 에서 작동하는 것이다.
            resource :user do
                # /signup 에서 넘어와야 하는 파라미터들 설정
                params do
                    requires :email, type: String
                    optional :password, type: String
                    optional :nick_name, type: String
                    optional :birth, type: Integer
                    optional :lang, type: String, values: ["eng", "kor", "jap", "chi"]
                end
                post :signup do
                    # db 에서 생성
                    result = User.create_or_update_account(params)
                    return result
                end

                # /authenticate 에서 넘어오는 파라미터
                # jwt 토큰을 돌려주어 로그인 할 수 있게 한다...
                params do
                    requires :email, type: String
                    requires :password, type: String
                end
                post :authenticate do
                    # TODO : last...??
                    user = User.where(email: params[:email]).last
                    
                    # 유저가 있을 때
                    if user
                        # 비밀번호를 확인해서 부여
                        if user.valid_password?(param[:password])
                            jwt_token = User.create_jwt_token(user.id)
                            # 돌려주는 형식은 front - back 사이에 협의되어야 할 일
                            return {
                                success: true,
                                jwt_token: jwt_token
                            }
                        else
                            return {
                                success: false,
                                message: "Wrong Password!"
                            }
                        end
                    else
                        return {
                            success: false,
                            message: "User Not Found!"
                        }
                    end
                end

                # /validate 를 통해 post
                # TODO : jwt 토큰을 refresh 시키는 개념인건가..?
                params do
                    # 현재 유저임을 확인만 하면 되는 것 같다
                end
                post :validate do
                    if current_user
                        # TODO : current_user 를 넘겨주는 이유는 무엇인가?
                        return {
                            success: true,
                            jwt_token: User.create_jwt_token(current_user.id),
                            user: current_user
                        }
                    else
                        return {
                            success: false,
                            jwt_token: nil,
                            user: nil
                        }
                    end
                end

                # /edit , post
                # TODO : user_setting 과의 차이는 무엇일까?
                params do 
                    optional :nick_name, type: String
                    optional :birth, type: Integer
                  end
                post :edit do 
                    authenticate!
          
                    # 각 파라미터로 넘어온 것들만 저장하는 것
                    if params[:nick_name] != nil 
                      current_user.nick_name = params[:nick_name]
                    end
          
                    if params[:birth] != nil 
                      current_user.birth = params[:birth]
                    end
          
                    current_user.save!
                    return {
                      success: true
                    }
                end

                # password 관련 된 것들을 수행할 apis
                # user/password/
                namespace :password do 
                    # /reset , post
                    # password 를 초기화 하기 위한 token...?
                    # -> Email 만 받게한 것은 공부목적인 것 같다.. 실제론 해당 email 에 이것이 전송되어야 하는게 아닌지...
                    params do 
                      requires :email, type: String
                    end
                    post :reset do 
                        user = User.find_by(email: params[:email])
                        unless user
                            return {
                                success: false,
                                message: "Account Not Found!"
                            }
                        end
          
                        payload = {
                            :user_id => user.id,
                            :exp => (Time.now + 30.minutes).to_i
                        }
          
                        token = JWT.encode payload, ENV["GENERATED_SECRET_KEY"], 'HS256' #!!!
                        user.reset_password_token = token
                        user.reset_password_sent_at = Time.now
                        user.save
            
                        #email! 
                        #mailgun. 
            
                        return {
                            success: true,
                            reset_password_token: token
                        }         
                    end
          
                    # /validate_token , get
                    # 비밀번호를 초기화 하기 위해 token을 받았는데...
                    # 왜 validate Token을 받는 거지??????????? 굳이 확인을 하는 작업이 필요할까.
                    # params do 
                    #   requires :reset_password_token, type: String
                    # end
                    # get :validate_token do 
                    #     decoded_token = JWT.decode params[:reset_password_token], ENV["GENERATED_SECRET_KEY"], true, { algorithm: 'HS256' }
                    #     user_id = decoded_token[0]["user_id"]
                    #     user = User.find_by(id:user_id)
                    #     exp = decoded_token[0]["exp"]
                        
                    #     # 발급받은 Token을 기간내에 사용하지 못했다면!
                    #     unless Time.now.to_i < exp
                    #         return {
                    #             success: false,
                    #             message: "Token has been expired. Try again"
                    #         }
                    #     end
                        
                    #     # 이제 비밀번호를 바꿀 수 있게 된 것이다?
                    #     return {
                    #         success: true,
                    #         # jwt_token: User.create_jwt_token(user_id),
                    #         message: 'Allowed!'
                    #     }
                    # end
          
                    desc "reset token is required in both cases (get grants, database update)"
                    # /update, post
                    # 패스워드를 바꾸는 작업 !
                    params do 
                        requires :reset_password_token, type: String
                        # TODO : token 안에 id 를 넣고서 이를 보냈는데 email을 다시 받아야 하는 이유가 있을까?
                        # requires :email, type: String
                        requires :new_password, type: String
                    end
                    post :update do
                        # user = User.where(email: params[:email]).last
                        decoded_token = JWT.decode params[:reset_password_token], ENV["GENERATED_SECRET_KEY"], true, { algorithm: 'HS256' }
                        user_id = decoded_token[0]["user_id"]
                        user = User.find_by(id:user_id)
                        exp = decoded_token[0]["exp"]
            
                        unless Time.now.to_i < exp
                            return {
                                success: false,
                                message: "Token has been expired. Try again"
                            }
                        end
                        
                        if user
                            user.password = params[:new_password]
                            begin
                                user.save!
                                return {
                                    success: true,
                                    jwt_token: User.create_jwt_token(user.id)
                                }
                            rescue => e
                                return {
                                    success: false,
                                    message: e.message.to_s
                                }
                            end
                        else
                            return {
                                success: false,
                                message: "user not found"
                            }
                        end
                    end
                end
            end
        end
    end
end