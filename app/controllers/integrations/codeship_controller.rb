require 'octokit'

class Integrations::CodeshipController < Integrations::BaseController
  protected

  def deploy?
    params[:build][:status] == 'success' &&
      !skip?
  end

  def skip?
    # Tddium doesn't send commit message, so we have to get creative
    repo_name = params[:build][:project_full_name]
    data = GITHUB.commit(repo_name, params[:build][:commit_id])

    contains_skip_token?(data.commit.message)

  rescue Octokit::Error => e
    Rails.logger.info("Error trying to grab commit: #{e.message}")
    # We'll assume that if we don't hear back, don't skip
    false
  end

  def branch
    params[:build][:branch]
  end

  def commit
    params[:build][:commit_id]
  end

  def user
    name = "Codeship"
    email = "tech.notifications@spoonrocket.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
