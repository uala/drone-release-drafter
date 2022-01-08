RSpec.describe ReleaseDrafter::Drafter do
  subject { described_class.new }

  let(:github_client) { double }

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
  let(:calver_config) do
    {
      'calver' => {
        'year' => '%y',
        'month' => '%m',
        'format' => '$YEAR.$MONTH-$MICRO'
      }
    }
  end

  before do
    stub_env('DRONE_SOURCE_BRANCH', 'branch')
    stub_env('PLUGIN_BRANCHES', ['branch'])
    stub_env('PLUGIN_CHANGELOG', changelog_config)
    stub_env('PLUGIN_CALVER', calver_config)
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

  describe '#draft!' do
    context 'branch not enabled' do
      before do
        stub_env('PLUGIN_BRANCHES', ['not-branch'])
      end

      it do
        expect(ReleaseDrafter::GithubClient).not_to receive(:new)
        expect(ReleaseDrafter::VersionResolver).not_to receive(:next_tag_name)
        expect(ReleaseDrafter::Changelog).not_to receive(:generate_body)
        expect(subject.draft!).to be_nil
      end
    end

    context 'missing latest release' do
      it do
        expect(ReleaseDrafter::GithubClient).to receive(:new).and_return(github_client)
        expect(github_client).to receive(:latest_release).and_return(nil)
        expect(ReleaseDrafter::VersionResolver).not_to receive(:next_tag_name)
        expect(ReleaseDrafter::Changelog).not_to receive(:generate_body)
        expect(subject.draft!).to be_nil
      end
    end

    context 'draft release' do
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
        expect(ReleaseDrafter::GithubClient).to receive(:new).and_return(github_client)
        expect(github_client).to receive(:latest_release).and_return(latest_release)
        expect(github_client).to receive(:merged_pull_requests_from_release).with(latest_release).and_return(merged_pull_requests)
        expect(ReleaseDrafter::VersionResolver).to receive(:next_tag_name).with(previous_tag: latest_release['tag_name'], config: changelog_config).and_return(tag_name)
        expect(ReleaseDrafter::Changelog).to receive(:generate_body).with(pulls: merged_pull_requests, changelog_config: changelog_config, previous_tag: latest_release['tag_name'], tag: tag_name).and_return(body)
        expect(github_client).to receive(:upsert_draft_release).with(tag_name: tag_name, release_name: tag_name, changelog: body)
        subject.draft!
      end
    end
  end
end