class CreateQuestions < ActiveRecord::Migration[6.1]
  def change
    create_table :questions do |t|
      t.string :content
      # date 가 아래처럼 저장이 될 것인데 이게 id 가 될지..?
      # 20210225
      t.integer :date
      t.timestamps
    end
  end
end
