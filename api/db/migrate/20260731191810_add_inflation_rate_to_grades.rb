class AddInflationRateToGrades < ActiveRecord::Migration[8.1]
  def change
    add_column :grades, :inflation_rate, :decimal, precision: 6, scale: 4, null: false, default: 0.06
  end
end
