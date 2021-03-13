module Grapes
    module V1
        class MemoAPI < Grapes::API
            helpers AuthHelpers

            resource :memo do
                params do
                    optional :yyyymmdd, type: String
                end

                # get do # /memo/
                #     question_translation = nil
                #     if params[:yyyymmdd]
                #         question = Question.find_by(date: params[:yyyymmdd])
                #     else
                #         time = Time.now.strftime("%Y%m%d").to_i
                #         question = Question.find_by(date: time)
                #     end

                #     unless question
                #         question = Question.last
                #     end
                # end
            end
        end
    end
end