RSpec.describe ReleaseDrafter::Changelog do
  describe '#self.generate_body' do
    let(:previous_tag) { 'v1.0.0' }
    let(:tag) { 'v1.1.0' }
    let(:repo) { 'test/test' }
    let(:pulls) do
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
          'title' => 'Pull request 2',
          'labels' => [{ 'name' => 'new feature' }],
          'user' => {
            'login' => 'user1'
          },
          'html_url' => 'https://github.com/test/test/pulls/2'
        },
        {
          'title' => 'Pull request 3',
          'labels' => [{ 'name' => 'dependencies' }],
          'user' => {
            'login' => 'user3'
          },
          'html_url' => 'https://github.com/test/test/pulls/3'
        },
        {
          'title' => 'Pull request 1',
          'labels' => [{ 'name' => 'test' }],
          'user' => {
            'login' => 'user2'
          },
          'html_url' => 'https://github.com/test/test/pulls/1'
        },
        {
          'title' => 'Pull request 5',
          'labels' => [{ 'name' => 'enhancement' }],
          'user' => {
            'login' => 'user2'
          },
          'html_url' => 'https://github.com/test/test/pulls/5'
        }
      ]
    end
    let(:config) do
      {
        'categories' => [
          {
            'title' => 'New Features',
            'labels' => ['new feature', 'enhancement']
          },
          {
            'title' => 'Bugfixes',
            'labels' => ['bugfix']
          },
          {
            'title' => 'Dependencies update',
            'labels' => ['dependencies']
          },
          {
            'title' => 'Other Changes',
            'labels' => ['*']
          }
        ]
      }
    end
    let(:expected_body) do
      <<~BODY
      <!-- Release notes generated using Drone plugin -->

      ## What's Changed
      ### New Features
      * Pull request 2 by @user1 in https://github.com/test/test/pulls/2
      * Pull request 5 by @user2 in https://github.com/test/test/pulls/5
      ### Bugfixes
      * Pull request 4 by @user1 in https://github.com/test/test/pulls/4
      ### Dependencies update
      * Pull request 3 by @user3 in https://github.com/test/test/pulls/3
      ### Other Changes
      * Pull request 1 by @user2 in https://github.com/test/test/pulls/1


      **Full Changelog**: https://github.com/test/test/compare/v1.0.0...v1.1.0
      BODY
    end

    it 'should pass' do
      expect(ReleaseDrafter::Changelog.generate_body(pulls: pulls, config: config, previous_tag: previous_tag, tag: tag, repo: repo)).to eq(expected_body)
    end
  end
end
