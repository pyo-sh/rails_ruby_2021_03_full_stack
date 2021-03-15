class CreateUserSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :user_settings do |t|
      t.integer :user_id
      t.string :lang
      # 이런 기능도 있었다고..?
      t.boolean :is_reminder_on
      t.boolean :is_public 
      # 알람 시간 기능도 만들 생각이였다..?
      t.integer :alarm_time_int
      t.timestamps
    end
  end
end