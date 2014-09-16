class AddHerokuAppNameToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :heroku_app_name, :string
  end
end
