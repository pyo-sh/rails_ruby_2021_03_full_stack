module Grapes
  module V1
    class MemoAPI < Grapes::API
      # v1.rb 의 AuthHelpers 역할 -> jwt 를 통해 User 를 확인
      helpers AuthHelpers

      # /memo/
      resource :memo do
        # 그냥 테스트인듯
        # /card/call
        # namespace :card do 
        #   get "call" do
        #     return {
        #       success: true,
        #       message: "gogo"
        #     }
        #   end
        # end
    
        # /memo/ 의 GET 통신
        params do 
          # 날짜를 굳이 optional로 받은 이유
          # 요구하는 날짜의 메모를 얻거나 / 요구하는게 없으면 오늘 날짜 메모이다
          # ex) 20210229
          optional :yyyymmdd, type: String
        end
        get do
          # Date 에 해당하는 question을 얻기위해 DB 에 접근하는 과정
          question_tranlsation = nil
          if params[:yyyymmdd]
            question = Question.find_by(date: params[:yyyymmdd])
          else
            #get the question of utc!
            time = Time.now.strftime("%Y%m%d").to_i
            question = Question.find_by(date: time)
          end
          # question을 구하지 못했다면.. 제일 최근 것을 GET
          unless question
            question = Question.last
          end

          # TODO : current_user의 설정을 어디서 하는지 찾아보자
          # 유저가 있을 경우 DB에서 setting 에 대한 설정 / memo 찾아 내기
          question_translation = nil
          memo = nil
          if current_user
            user_setting = UserSetting.where(user_id: current_user.id).last
            if user_setting
              lang = user_setting.lang
              question_translation = QuestionTranslation.where(question_id: question.id).where(lang: lang).last
            end
            memo = Memo.where(user_id: current_user.id, question_id: question.id).last
          end 
          
          # question의 date 를 다듬어서 return 하기
          date = question.date.to_s
          question = question.as_json

          yyyy = date[0..3] 
          mm = date[4..5]
          dd = date[6..7]

          question["date_str"] = Time.new(yyyy.to_s, mm.to_s, dd.to_s, "0", "0", "0", "+09:00").strftime("%Y %B, %d")

          return {
            question: question,
            question_translation: question_tranlsation,
            memo: memo,
            success: true
          }
        end
        
        # /memo/list, GET 통신
        # memo 들의 list들을 받아오는 역할
        params do 
          # question의 id가 date 인가..?
          # ex) 20210229
          optional :question_id, type: Integer
        end
        get :list do
          # question 구하기
          if params[:question_id]
            question = Question.find_by(id: params[:question_id])
            question_id = question.id
          else
            time = Time.now.strftime("%Y%m%d").to_i
            question = Question.find_by(date: time)
            question_id = question.id
          end

          # question을 통해서 memo 구하기
          memos = Memo.where(question_id: question_id).all.first(5)

          # memo 에 대한 like 여부 구하기
          user_ids = memos.map(&:user_id)
          # DB 에서 계속 Users 를 탐색하는 것을 방지하기 위함
          users = User.select(:id, :nick_name).where(id: user_ids)
          # DB 에서 계속 내가 좋아요 누른 memo 들을 탐색하는 것을 방지하기 위함
          likes = Like.where(user_id: current_user.id, memo_id: memos.map(&:id))

          # memo 와 memo의 user, memo 를 내가 좋아요를 눌렀는지에 대한 여부 를 포함한 memo 들의 list
          list = memos.map do |memo|
            user = users.find{|user| user.id == memo.user_id}
            my_like = likes.find{|like| like.memo_id == memo.id}

            memo = memo.as_json
            memo["user"] = {nick_name: user.nick_name}

            memo["do_i_like"] = true if my_like 
            memo
          end

          return {
            success: true,
            list: list
          }
        end
        
        # /memo/create , POST
        # create 이므로 안의 내용이 필요하다.
        params do
          requires :content, type: String
          requires :question_id, type: Integer
          requires :is_public, type: Boolean
        end
        post :create do
          # current_user 가 생성하는 내용이여야 할 것이다.
          # 다른 유저가 나의 메모를 생성하는 일은 없어야지..
          authenticate!

          # 오늘에 해당하는 Memo (question_id) 가 넘어올 때
          # 이미 존재한다면 만들 수 없어야 할 것이다...
          begin
            Memo.create!({
              user_id: current_user.id,
              content: params[:content],
              question_id: params[:question_id],
              is_public: params[:is_public]
            })
          rescue => e 
            return {
              success: false,
              message: "Already Submitted"
            }
          end

          return {
            success: true
          }
        end
        
        # /memo/edit , POST
        # is_public 을 변경하거나, content 를 변경하거나 를 수행하는 역할이다
        params do 
          requires :memo_id, type: Integer
          optional :is_public, type: Boolean
          optional :content, type: String
        end
        post :edit do
          # 수정하는 사람이 나여야 할 것이다!
          authenticate!

          # 없는 메모를 찾는 그런 사람은 아니여야 할 것이야...
          memo = Memo.find_by(id: params[:memo_id])
          unless memo
            return {
              success: false,
              message: "Not Existing"
            }
          end

          # 다른 사람이 생성한 메모에 접근하지 못하도록 조치를 취하는 것
          if memo.user_id != current_user.id
            return {
              success: false,
              message: "Unauthorized Contact"
            }
          end

          # is_public 에 대한 수정
          if params[:is_public] != nil
            memo.is_public = params[:is_public]
          end

          # content 에 대한 수정
          if params[:content] != nil
            memo.content = params[:content] 
          end

          # DB 에 수정했다!
          memo.save!
          # TODO : 완료 메세지를 넘겨줄지 말지에 대한 내용은 ...
          # Front-end 단에서 확인하도록 하자
        end
        
        # /memo/delete , POST
        # memo 를 삭제하는 작업
        params do 
          requires :id, type: Integer
        end
        post :delete do 
          # 로그인도 안하고 메모를 삭제하는 이가 있나?
          authenticate!

          memo = Memo.find_by(id: params[:id])
          unless memo
            return {
              success: false,
              message: "Not Existing"
            }
          end

          # 다른 사람이 나의 MEMO 를 건들지 못하도록 하자
          if memo.user_id != current_user.id
            return {
              success: false,
              message: "Unauthorized Contact"
            }
          end

          # DB 에서 삭제!
          memo.delete
          # TODO : 삭제에 대한 Column 추가 및 잠시 저장하는 역할을 추가할 수 있다..
          # TODO : 완료 메세지를 넘겨줄지?
        end
        
        # /memo/like , POST
        # 메모에 좋아요를 누르는 역할 !
        params do
          requires :id, type: Integer
        end
        post :like do
          # 로그인을 안하고 좋아요를 누르는 사람이 있다?
          authenticate!

          memo = Memo.find_by(id: params[:id])
          # 공개하지 않은 메모인데 like 을 누르려 접근을 하다니
          unless memo.is_public
            return {
              success: false,
              message: "Private Memo!"
            }
          end

          # 정말 좋아요를 누르지 않은 사람인지 확인하는 단계
          like = Like.where(user_id: current_user.id).where(memo_id: params[:id]).last

          # 누르지 않은 사람이면 허락!
          unless like
            Like.create!({
              user_id: current_user.id,
              memo_id: params[:id]
            })
          end

          # Memo 에 대한 save
          count = Like.where(memo_id: params[:id]).count

          memo.likes = count
          memo.save!

          return {
            success: true
          }
        end
        
        # /memo/unlike , POST
        # 좋아요를 취소하는 슬픈 상황인거지...
        params do
          requires :id, type: Integer
        end
        post :unlike do
          # 좋아요 테러를 위해 비로그인으로 그런 짓을 하진 않겠지? ㅎㅎ;
          authenticate!

          memo = Memo.find_by(id: params[:id])
          # public 메모에게만 접근하도록 하자.
          # 이 사람이 좋아요 받고 닫아놓으면 좋튀 못하게 되는 것이야...
          unless memo.is_public
            return {
              success: false,
              message: "Private Memo!"
            }
          end

          like = Like.where(user_id: current_user.id).where(memo_id: params[:id]).last

          # like 를 누른 사람이면 정말 삭제시키자.
          if like
            like.delete
          end

          # Memo 에 대한 update
          count = Like.where(memo_id: params[:id]).count

          memo.likes = count
          memo.save!

          return {
            success: true
          }
        end

        # /memo/calendar , GET 통신
        # 달력에 대해서 해당하는 날짜의 Memo 가 있으면 그를 나타내는 내용을 내보내고 싶은 것 같다.
        # 나는 아직 Calender 를 구현할 지에 대한 고려를 하고있다.
        # DB 에만 아래 내용을 넣어두고 좀 더 고려해보자
        # params do
        #   requires :year, type: Integer
        #   # ex) 202102 or 0
        #   requires :month, type: Integer
        # end
        # get :calendar do
        #   # current_user 에 대한 내용이 없다면 Error!
        #   authenticate!
          
        #   # params 들이 있는지 없는지에 대한 여부...
        #   # TODO : requires 로 안해도 될 것 같은데..?
        #   if params[:year] != 0 && params[:month] != 0
        #     yyyy = params[:year]
        #     mm = params[:month]
        #   else
        #     time = Time.now.in_time_zone("Asia/Seoul")
        #     yyyy = time.strftime("%Y")
        #     mm = time.strftime("%m")
        #   end
          
        #   # TODO : timezone ..? 
        #   time = Time.new(yyyy.to_s, mm.to_s, 3, '0')
        #   start_time = time.in_time_zone(current_user.timezone).beginning_of_month          
        #   end_time = start_time + 1.month
        #   # 시작 지점 ~ 끝 지점 에서 있는 memo 들을 불러온다
        #   memos = Memo.where(user_id: current_user.id).where("created_at >= ?", start_time).where("created_at < ?", end_time)
          
        #   # 각 메모들이 있는 것에 대한 Day 를 반환한다.
        #   created_ats = memos.map{|memo|
        #     memo.created_at.in_time_zone(current_user.timezone).strftime("%d").to_i
        #   }.uniq

        #   return {
        #     success: true,
        #     yyyy: yyyy,
        #     mm: mm,
        #     created_ats: created_ats
        #   }
        # end
        
        # follow, unfollow 기능을 추가해야 하는 것인가는 고민중이야!
        # params do 
        #   requires :target_user_id, type: Integer
        # end
        # post :follow do 
        #   authenticate!

        #   begin
        #     follow = Follow.create!({
        #       user_id: current_user.id,
        #       target_user_id: params[:target_user_id]
        #     })
        #   rescue => e
        #     return {  
        #       success: false,
        #       message: e.message.to_s
        #     }
        #   end

        #   return {
        #     success: true,
        #   }
        # end
      end
    end
  end
end