class Release < ActiveRecord::Base
  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true

  before_create :assign_release_number

  def self.sort_by_version
    order(number: :desc)
  end

  def to_param
    version
  end

  def currently_deploying_stages
    project.stages.where_reference_being_deployed(version)
  end

  def deployed_stages
    @deployed_stages ||= project.stages.select {|stage| stage.current_release?(self) }
  end

  def changeset
    @changeset ||= Changeset.new(project.github_repo, previous_release.try(:commit), commit)
  end

  def previous_release
    project.release_prior_to(self)
  end

  def version
    "v#{number}"
  end

  def author
    super || NullUser.new(author_id)
  end

  def self.find_by_version!(version)
    find_by_number!(version[/\Av(\d+)\Z/, 1].to_i)
  end

  private

  def assign_release_number
    if project.heroku_app_name.present?
      heroku_release_number = `heroku releases --app #{project.heroku_app_name} | sed -n 2p | awk '{print $1}'`.strip
      latest_release_number = heroku_release_number.match(/v(\d+)/)[1].to_i rescue nil
    end
    latest_release_number ||= project.releases.last.try(:number) || 0
    self.number = latest_release_number + 1
  end
end
