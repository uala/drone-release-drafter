require 'release_drafter/github_client'
require 'release_drafter/release_changelog'
require 'release_drafter/release_version'
require 'release_drafter/version'
require 'logger'

module ReleaseDrafter
  class Error < StandardError;
  end

  # When configuration file is not found or not set
  MissingConfig = Class.new(Error)

  class Drafter
    attr_reader :logger, :config, :current_branch

    def initialize
      @config         = {}
      @current_branch = ENV.fetch('DRONE_SOURCE_BRANCH')
      logger.debug %Q{Running plugin for branch "#{current_branch}"}
    end

    def load_config!
      @config['changelog'] = ENV.fetch('PLUGIN_CHANGELOG', {})
      @config['calver'] = ENV.fetch('PLUGIN_CALVER', {})
      logger.info "Plugin configuration: #{@config}"
    end

    # Dry-run flag
    def dry_run?
      !ENV['PLUGIN_DRY_RUN'].to_s.empty?
    end

    def color?
      ENV.fetch('PLUGIN_COLORS', 'true') != 'false'
    end

    def draft!
      # If no enviroments applicable ENVs will exit with status code 1
      logger.warn("Release drafting not enabled for #{current_branch}") and return if (allowed_branches = ENV.fetch('PLUGIN_BRACHES')) && !allowed_branches.include?(current_branch)
      # Actual drafting
      logger.info "Drafting release for #{current_branch} branch..."
      github_client = GithubClient.new(
        repository: ENV['DRONE_REPO'].to_s.downcase,
        access_token: ENV['GITHUB_PUBLISH_TOKEN']
      )
      latest_release = github_client.latest_release
      # If no comparison release exists will exit with status code 1
      logger.warn("Release drafting not enabled for first release") and return unless latest_release
      # Get merged pull requests
      merged_pull_requests = github_client.merged_pull_requests_from_release(latest_release)
      logger.info "Merged pull requests from release #{latest_release['tag_name']}: #{merged_pull_requests.map { |pull| pull[:title] }}"
      # Get new tag and body
      tag_name = ReleaseVersion.next_tag_name(previous_tag: latest_release['tag_name'], config: @config['changelog'])
      body = generate_body(
        pulls: merged_pull_requests,
        changelog_config: @config['changelog'],
        previous_tag: latest_release['tag_name'],
        tag: tag_name
      )
      logger.info "New drafting tag name is: #{tag}"
      # Draft release
      github_client.upsert_draft_release(
        tag_name: tag_name,
        release_name: tag_name,
        changelog: body
      )
    end

    private

    # Logger for output
    def logger
      @_logger ||= begin
        Logger.new($stdout).tap do |l|
          l.level = ENV.fetch('PLUGIN_LOGGING', 'info')
        end
      end
    end
  end
end
