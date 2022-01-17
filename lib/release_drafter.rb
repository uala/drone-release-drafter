require 'release_drafter/github_client'
require 'release_drafter/changelog'
require 'release_drafter/version_resolver'
require 'colorize'
require 'logger'
require 'yaml'

module ReleaseDrafter
  class Error < StandardError;
  end

  # When configuration file is not found or not set
  MissingConfig = Class.new(Error)

  class Drafter
    attr_reader :logger, :config, :current_branch, :repository

    def initialize
      @config = {}
      @repository = ENV.fetch('DRONE_REPO').to_s.downcase
      @current_branch = ENV.fetch('DRONE_SOURCE_BRANCH')
      logger.debug %Q{Running plugin for branch "#{current_branch}"}
      load_config!
    end

    def load_config!
      @config['changelog'] = YAML.safe_load(ENV.fetch('PLUGIN_CHANGELOG', ''))
      @config['version_resolver'] = YAML.safe_load(ENV.fetch('PLUGIN_VERSION_RESOLVER', ''))
      logger.info "Plugin configuration: ".light_blue + "#{@config}"
    end

    # Dry-run flag
    def dry_run?
      !ENV['PLUGIN_DRY_RUN'].to_s.empty?
    end

    def color?
      ENV.fetch('PLUGIN_COLORS', 'true') != 'false'
    end

    def draft!
      @github_client = GithubClient.new(
        repository: repository,
        access_token: ENV['GITHUB_PUBLISH_TOKEN']
      )
      return unless should_run?

      # Actual drafting
      logger.info "Drafting release for #{current_branch} branch...".green
      latest_release = @github_client.latest_release
      # Get merged pull requests
      merged_pull_requests = @github_client.merged_pull_requests_from_release(latest_release)
      logger.info "Merged pull requests from release #{latest_release['tag_name']}: ".yellow + \
                  "#{merged_pull_requests.map { |pull| pull['title'] }}"
      # Get new tag and body
      tag_name = VersionResolver.next_tag_name(
        previous_tag: latest_release['tag_name'],
        config: @config['version_resolver']
      )
      body = Changelog.generate_body(
        pulls: merged_pull_requests,
        config: @config['changelog'],
        previous_tag: latest_release['tag_name'],
        tag: tag_name,
        repository: repository
      )
      draft = !should_release?(merged_pull_requests)
      logger.info "New drafting tag name details:\n".green + \
                  "Tag: #{tag_name}\n" + \
                  "Draft: #{draft}\n" + \
                  "Body:\n#{body}"
      # Draft release
      if !dry_run?
        drafted_release = @github_client.upsert_draft_release(
          tag_name: tag_name,
          release_name: tag_name,
          changelog: body,
          draft: draft
        )
        logger.info "Drafted release #{drafted_release['tag_name']}: ".green + \
                    "#{drafted_release['html_url']}"
      end
    end

    private

    def should_run?
      # If no enviroments applicable ENVs will exit with status code 1
      logger.warn("Release drafting not enabled for #{current_branch}".red) and return false if (allowed_branches = ENV.fetch('PLUGIN_BRANCHES')) && !allowed_branches.include?(current_branch)
      # If no comparison release exists will exit with status code 1
      logger.warn("Release drafting not enabled for first release".red) and return false unless @github_client.latest_release
      # If HEAD enforced but not on HEAD will exit with status code 1
      logger.warn("Release drafting enabled HEAD only".red) and return false unless ENV.fetch('PLUGIN_ENFORCE_HEAD', nil).to_s.empty? || @github_client.head_commit_sha == ENV['DRONE_COMMIT_SHA']

      true
    end

    def should_release?(merged_pull_requests)
      release_labels = YAML.safe_load(ENV.fetch('PLUGIN_RELEASE_LABELS', ''))
      return false unless ENV['DRONE_BUILD_STATUS'] == 'success' && release_labels&.any? && merged_pull_requests&.any?

      merged_pull_requests.all? do |pull|
        (pull['labels'].map { |l| l['name'] } & release_labels).any?
      end
    end

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
