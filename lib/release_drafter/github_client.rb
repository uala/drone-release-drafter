require 'octokit'

module ReleaseDrafter
  class GithubClient
    def initialize(repository:, access_token:, committish_branch: 'main')
      @repository = repository
      @client = Octokit::Client.new(access_token: access_token)
      @committish_branch = committish_branch
    end

    def latest_release
      @client.latest_release(@repository)
    end

    def merged_pull_requests_from_release(release)
      _get_commit_associated_closed_pulls(_get_commits_from_ref(release['tag_name']))
    end

    def upsert_draft_release(tag_name:, release_name:, changelog:)
      release_attrs = {
        tag_name: tag_name,
        name: release_name,
        body: changelog,
        draft: true,
        target_commitish: @committish_branch
      }

      if (draft_release = _latest_draft_release)
        @client.update_release(draft_release['url'], release_attrs)
      else
        @client.create_release(@repo, new_tag, release_attrs)
      end
    end

    private

    def _get_commits_from_ref(ref)
      @client.compare(@repository, ref, @committish_branch)['commits']
    end

    def _get_commit_associated_closed_pulls(commits)
      commits.flat_map do |commit|
        @client.commit_pulls(@repository, commit.sha)
      end.select do |pull|
        pull['state'] == 'closed'
      end
    end

    def _latest_draft_release
      @client.releases(@repository).find do |release|
        release['draft'] == true
      end
    end
  end
end
