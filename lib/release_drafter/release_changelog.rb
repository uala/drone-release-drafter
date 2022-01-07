module ReleaseDrafter
  class ReleaseChangelog
    def self.generate_body(pulls:, changelog_config:, previous_tag:, tag:, repo:)
      pulls_changelog = _categorize_pulls(pulls: pulls, pulls_config: changelog_config['categories']).map do |(category, category_pulls)|
        category_changelog = category_pulls.map { |pull| "* #{pull['title']} by @#{pull['user']['login']} in #{pull['html_url']}" }.join("\n")
        <<~BODY
          ### #{category}
          #{category_changelog}
        BODY
      end

      <<~BODY
        <!-- Release notes generated using Drone plugin -->

        ## What's Changed
        #{pulls_changelog.join}

        **Full Changelog**: https://github.com/#{repo}/compare/#{previous_tag}...#{tag}
      BODY
    end

    private

    def self._categorize_pulls(pulls:, pulls_config:)
      categorized = {}

      wildcard_categories = pulls_config.select do |config|
        config['labels'].include?('*')
      end
      pulls.each do |pull|
        categories = pulls_config.select do |config|
          (pull['labels'].map { |l| l['name'] } & config['labels']).any?
        end
        categories = wildcard_categories if categories.empty?

        categories.each do |config|
          categorized[config['title']] ||= []
          categorized[config['title']] << pull
        end
      end

      pulls_config.map do |config|
        [
          config['title'],
          categorized[config['title']].sort_by { |pull| pull['merged_at'] }
        ] if categorized[config['title']]
      end.compact
    end
  end
end
