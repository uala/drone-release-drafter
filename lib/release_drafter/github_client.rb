require 'octokit'

module ReleaseDrafter
  class GithubClient
    def initialize(repository:, access_token:, committish_branch: 'main')
      @repository = repository
      @client = Octokit::Client.new(access_token: access_token)
      @committish_branch = committish_branch
    end

    def latest_release
      # Cannot use @client.latest_release because the release sorting is not consistent
      # with API specs. It should follow release.commit.created_at but it is not, so
      # it's better to retrieve latest releases and pick the latest one using fixed
      # sorting logic.
      _latest_release
    end

    def merged_pull_requests_from_release(release)
      _get_commit_associated_closed_pulls(_get_commits_from_ref(release['tag_name']))
    end

    def upsert_draft_release(tag_name:, release_name:, changelog:, draft: true)
      release_attrs = {
        tag_name: tag_name,
        name: release_name,
        body: changelog,
        draft: !!draft,
        target_commitish: @committish_branch
      }

      if (draft_release = _latest_release(draft: true))
        @client.update_release(draft_release['url'], release_attrs)
      else
        @client.create_release(@repository, tag_name, release_attrs)
      end
    end

    def head_commit_sha
      @client.commits(@repository, @committish_branch, { per_page: 1 }).first.sha
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

    def _latest_release(draft: false)
      @client.releases(@repository, per_page: 100).sort_by do |release|
        release.published_at || release.created_at
      end.reverse.find do |release|
        release.draft? == draft
      end
    end
  end
end
