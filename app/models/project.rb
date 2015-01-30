class Project < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true

  validates :name, :repository_url, presence: true
  before_create :generate_token
  after_save :clone_repository, if: :repository_url_changed?
  before_update :clean_old_repository, if: :repository_url_changed?
  after_soft_delete :clean_repository

  has_many :releases
  has_many :stages, dependent: :destroy
  has_many :deploys, through: :stages
  has_many :jobs, -> { order(created_at: :desc) }
  has_many :webhooks
  has_many :commands
  has_many :macros

  accepts_nested_attributes_for :stages

  scope :alphabetical, -> { order('name') }

  def repo_name
    name.parameterize('_')
  end

  def last_released_with_commit?(commit)
    last_release = releases.order(:id).last
    last_release && last_release.commit == commit
  end

  # Creates a new Release, incrementing the release number. If the Release
  # fails to save, `#persisted?` will be false.
  #
  # Returns the Release.
  def create_release(attrs = {})
    release = build_release(attrs)
    release.save
    release
  end

  def build_release(attrs = {})
    latest_release_number = retrieve_latest_release_number
    release_number = latest_release_number + 1
    releases.build(attrs.merge(number: release_number))
  end

  def auto_release_stages
    stages.deployed_on_release
  end

  def manage_releases?
    releases.any?
  end

  # Whether to create new releases when the branch is updated.
  #
  # branch - The String name of the branch in question.
  #
  # Returns true if new releases should be created, false otherwise.
  def create_releases_for_branch?(branch)
    release_branch == branch
  end

  def changeset_for_release(release)
    prior_release = release_prior_to(release)
    prior_commit = prior_release && prior_release.commit
    Changeset.find(github_repo, prior_commit, release.commit)
  end

  # The user/repo part of the repository URL.
  def github_repo
    # GitHub allows underscores, hyphens and dots in repo names
    # but only hyphens in user/organisation names (as well as alphanumeric).
    repository_url.scan(/:([A-Za-z0-9-]+\/[\w.-]+)\.git$/).join
  end

  def repository_directory
    @repository_directory ||= Digest::MD5.hexdigest([repository_url, id].join)
  end

  def repository_homepage
    "//#{Rails.application.config.samson.github.web_url}/#{github_repo}"
  end

  def webhook_stages_for_branch(branch)
    webhooks.for_branch(branch).map(&:stage)
  end

  def release_prior_to(release)
    releases.where('number < ?', release.number).order(:number).last
  end

  def repository
    @repository ||= GitRepository.new(repository_url: repository_url, repository_dir: repository_directory)
  end

  def with_lock(output: StringIO.new, holder:, error_callback: nil, timeout: 10.minutes, &block)
    callback = if error_callback.nil?
      proc { |owner| output.write("Waiting for repository while cloning for #{owner}\n") if Time.now.to_i % 10 == 0 }
    else
      error_callback
    end
    MultiLock.lock(id, holder, timeout: timeout, failed_to_lock: callback, &block)
  end

  private

  def retrieve_latest_release_number
    if heroku_app_name.present?
      heroku_release_number = `heroku releases --app #{heroku_app_name} | sed -n 2p | awk '{print $1}'`.strip
      latest_release_number = heroku_release_number.match(/v(\d+)/)[1].to_i rescue nil
    end
    latest_release_number ||= releases.last.try(:number) || 0
  end

  def permalink_base
    repository_url.to_s.split('/').last.to_s.sub(/\.git/, '')
  end

  def generate_token
    self.token = SecureRandom.hex
  end

  def clone_repository
    Thread.new do
      begin
        output = StringIO.new
        with_lock(output: output, holder: 'Initial Repository Setup') do
          is_cloned = repository.clone!(executor: TerminalExecutor.new(output), from: repository_url, mirror: true)
          log.error("Could not clone git repository #{repository_url} for project #{name} - #{output.string}") unless is_cloned
        end
      rescue => e
       alert_clone_error!(e)
      end
    end
  end

  def clean_repository
    repository.clean!
  end

  private

  def log
    Rails.logger
  end

  def clean_old_repository
    GitRepository.new(repository_url: repository_url_was, repository_dir: old_repository_dir).clean!
    @repository, @repository_directory = nil
  end

  def old_repository_dir
    Digest::MD5.hexdigest([repository_url_was, id].join)
  end

  def alert_clone_error!(exception)
    message = "Could not clone git repository #{repository_url} for project #{name}"
    log.error("#{message} - #{exception.message}")
    if defined?(Airbrake)
      Airbrake.notify(exception,
        error_message: message,
        parameters: {
          project_id: id
        }
      )
    end
  end

end
