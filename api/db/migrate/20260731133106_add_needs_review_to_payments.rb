class AddNeedsReviewToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :needs_review, :boolean, null: false, default: false
    add_index :payments, [:grade_id, :needs_review]
  end
end
