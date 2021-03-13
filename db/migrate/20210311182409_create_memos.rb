class CreateMemos < ActiveRecord::Migration[6.1]
  def change
    create_table :memos do |t|
      t.integer :memoid
      t.string :title
      t.text :content
      t.timestamps
    end
  end
end
