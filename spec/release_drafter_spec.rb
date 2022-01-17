RSpec.describe ReleaseDrafter::Drafter do
  subject { described_class.new }

  let(:repository) { 'test/test' }
  let(:access_token) { '<GITHUB_TOKEN>' }
  let(:github_client) { double }

  let(:input_changelog_config) do
    <<~YAML
      categories:
        - title: New Features
          labels:
            - new feature
            - enhancement
    YAML
  end
  let(:changelog_config) do
    {
      'categories' => [
        {
          'title' => 'New Features',
          'labels' => ['new feature', 'enhancement']
        }
      ]
    }
  end
  let(:input_version_resolver_config) do
    <<~YAML
      calver:
        year: '%y'
        month: '%m'
        format: '$YEAR.$MONTH-$MICRO'
    YAML
  end
  let(:version_resolver_config) do
    {
      'calver' => {
        'year' => '%y',
        'month' => '%m',
        'format' => '$YEAR.$MONTH-$MICRO'
      }
    }
  end
  let(:input_release_labels) do
    <<~YAML
      - automatic release
    YAML
  end

  before do
    stub_env('DRONE_REPO', repository)
    stub_env('GITHUB_PUBLISH_TOKEN', access_token)
    stub_env('DRONE_SOURCE_BRANCH', 'branch')
    stub_env('PLUGIN_BRANCHES', ['branch'])
    stub_env('PLUGIN_CHANGELOG', input_changelog_config)
    stub_env('PLUGIN_VERSION_RESOLVER', input_version_resolver_config)
    stub_env('PLUGIN_ENFORCE_HEAD', true)
    stub_env('DRONE_COMMIT_SHA', 'abc')
    stub_env('PLUGIN_RELEASE_LABELS', input_release_labels)
  end

  describe '#dry_run?' do
    it 'is true' do
      stub_env('PLUGIN_DRY_RUN', true)
      expect(subject.dry_run?).to eq true
    end

    it 'is false' do
      stub_env('PLUGIN_DRY_RUN', nil)
      expect(subject.dry_run?).to eq false
    end
  end

  describe '#should_run?' do
    context 'branch not enabled' do
      before do
        stub_env('PLUGIN_BRANCHES', ['not-branch'])
      end

      it do
        expect(subject.send(:should_run?)).to eq false
      end
    end

    context 'missing latest release' do
      it do
        subject.instance_variable_set(:@github_client, github_client)
        expect(github_client).to receive(:latest_release).and_return(nil)
        expect(subject.send(:should_run?)).to eq false
      end
    end

    context 'not on HEAD' do
      let(:latest_release) do
        {
          'tag_name' => '22.01-2'
        }
      end

      it do
        subject.instance_variable_set(:@github_client, github_client)
        expect(github_client).to receive(:latest_release).and_return(latest_release)
        expect(github_client).to receive(:head_commit_sha).and_return('def')
        expect(subject.send(:should_run?)).to eq false
      end

      context 'enabled' do
        before do
          stub_env('PLUGIN_ENFORCE_HEAD', nil)
        end

        it do
          subject.instance_variable_set(:@github_client, github_client)
          expect(github_client).to receive(:latest_release).and_return(latest_release)
          expect(subject.send(:should_run?)).to eq true
        end
      end
    end
  end

  describe '#draft!' do
    context 'draft release' do
      let(:latest_release) do
        {
          'tag_name' => '22.01-2'
        }
      end
      let(:drafted_release) do
        {
          'tag_name' => '22.01-3',
          'html_url' => 'https://github.com/test/test/releases/tag/22.01-3'
        }
      end
      let(:merged_pull_requests) do
        [
          {
            'title' => 'Pull request 4',
            'labels' => [{ 'name' => 'bugfix' }],
            'user' => {
              'login' => 'user1'
            },
            'html_url' => 'https://github.com/test/test/pulls/4'
          },
          {
            'title' => 'Pull request 6',
            'labels' => [{ 'name' => 'automatic release' }],
            'user' => {
              'login' => 'user1'
            },
            'html_url' => 'https://github.com/test/test/pulls/6'
          }
        ]
      end
      let(:tag_name) { '22.01-3' }
      let(:body) { 'Release body' }

      it do
        expect(ReleaseDrafter::GithubClient).to receive(:new).with(repository: repository, access_token: access_token).and_return(github_client)
        expect(github_client).to receive(:latest_release).and_return(latest_release).twice
        expect(github_client).to receive(:head_commit_sha).and_return('abc')
        expect(github_client).to receive(:merged_pull_requests_from_release).with(latest_release).and_return(merged_pull_requests)
        expect(ReleaseDrafter::VersionResolver).to receive(:next_tag_name).with(previous_tag: latest_release['tag_name'], config: version_resolver_config).and_return(tag_name)
        expect(ReleaseDrafter::Changelog).to receive(:generate_body).with(pulls: merged_pull_requests, config: changelog_config, previous_tag: latest_release['tag_name'], tag: tag_name, repository: repository).and_return(body)
        expect(github_client).to receive(:upsert_draft_release).with(tag_name: tag_name, release_name: tag_name, changelog: body, draft: true).and_return(drafted_release)
        subject.draft!
      end
    end

    context 'automatic release' do
      let(:latest_release) do
        {
          'tag_name' => '22.01-2'
        }
      end
      let(:drafted_release) do
        {
          'tag_name' => '22.01-3',
          'html_url' => 'https://github.com/test/test/releases/tag/22.01-3'
        }
      end
      let(:merged_pull_requests) do
        [
          {
            'title' => 'Pull request 6',
            'labels' => [{ 'name' => 'automatic release' }],
            'user' => {
              'login' => 'user1'
            },
            'html_url' => 'https://github.com/test/test/pulls/6'
          }
        ]
      end
      let(:tag_name) { '22.01-3' }
      let(:body) { 'Release body' }

      it do
        expect(ReleaseDrafter::GithubClient).to receive(:new).with(repository: repository, access_token: access_token).and_return(github_client)
        expect(github_client).to receive(:latest_release).and_return(latest_release).twice
        expect(github_client).to receive(:head_commit_sha).and_return('abc')
        expect(github_client).to receive(:merged_pull_requests_from_release).with(latest_release).and_return(merged_pull_requests)
        expect(ReleaseDrafter::VersionResolver).to receive(:next_tag_name).with(previous_tag: latest_release['tag_name'], config: version_resolver_config).and_return(tag_name)
        expect(ReleaseDrafter::Changelog).to receive(:generate_body).with(pulls: merged_pull_requests, config: changelog_config, previous_tag: latest_release['tag_name'], tag: tag_name, repository: repository).and_return(body)
        expect(github_client).to receive(:upsert_draft_release).with(tag_name: tag_name, release_name: tag_name, changelog: body, draft: false).and_return(drafted_release)
        subject.draft!
      end
    end

    context 'dry run' do
      let(:latest_release) do
        {
          'tag_name' => '22.01-2'
        }
      end
      let(:merged_pull_requests) do
        [
          {
            'title' => 'Pull request 4',
            'labels' => [{ 'name' => 'bugfix' }],
            'user' => {
              'login' => 'user1'
            },
            'html_url' => 'https://github.com/test/test/pulls/4'
          }
        ]
      end
      let(:tag_name) { '22.01-3' }
      let(:body) { 'Release body' }

      it do
        stub_env('PLUGIN_DRY_RUN', true)
        expect(ReleaseDrafter::GithubClient).to receive(:new).with(repository: repository, access_token: access_token).and_return(github_client)
        expect(github_client).to receive(:latest_release).and_return(latest_release).twice
        expect(github_client).to receive(:head_commit_sha).and_return('abc')
        expect(github_client).to receive(:merged_pull_requests_from_release).with(latest_release).and_return(merged_pull_requests)
        expect(ReleaseDrafter::VersionResolver).to receive(:next_tag_name).with(previous_tag: latest_release['tag_name'], config: version_resolver_config).and_return(tag_name)
        expect(ReleaseDrafter::Changelog).to receive(:generate_body).with(pulls: merged_pull_requests, config: changelog_config, previous_tag: latest_release['tag_name'], tag: tag_name, repository: repository).and_return(body)
        expect(github_client).not_to receive(:upsert_draft_release)
        subject.draft!
      end
    end
  end
end
