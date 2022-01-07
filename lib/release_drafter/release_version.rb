module ReleaseDrafter
  class ReleaseVersion
    VALID_TAG_PARTS = %w[year month day micro].freeze

    def self.next_tag_name(previous_tag:, config:)
      if (calver_config = config['calver'])
        tag_parts = {
          'year' => calver_config['year'] ? Time.now.strftime(calver_config['year']) : nil,
          'month' => calver_config['month'] ? Time.now.strftime(calver_config['month']) : nil,
          'day' => calver_config['day'] ? Time.now.strftime(calver_config['year']) : nil,
          'micro' => '0'
        }
        previous_tag_parts = _extract_tag_parts(previous_tag, calver_config)

        if !%w[year month day].any? { |part| previous_tag_parts[part] && tag_parts[part] && (previous_tag_parts[part] != tag_parts[part]) }
          tag_parts['micro'] = previous_tag_parts['micro'].next
        end

        tag_name = calver_config['format']
        VALID_TAG_PARTS.each do |part|
          tag_name = tag_name.gsub("$#{part.upcase}", tag_parts[part]) if tag_parts[part]
        end
        tag_name
      else
        raise 'Unable to detect new version'
      end
    end

    private

    def self._extract_tag_parts(tag, config)
      regex = config['format']
      VALID_TAG_PARTS.each do |part|
        regex = regex.gsub("$#{part.upcase}", "(?<#{part}>\\d+)")
      end
      tag.match(regex).named_captures
    end
  end
end
