require 'timecop'

RSpec.describe ReleaseDrafter::ReleaseVersion do
  describe '#self.next_tag_name' do
    let(:config) do
      {
        'calver' => {
          'year' => '%y',
          'month' => '%m',
          'format' => '$YEAR.$MONTH-$MICRO'
        }
      }
    end

    it 'year increment' do
      Timecop.freeze(Time.new(2022, 1, 1)) do
        expect(ReleaseDrafter::ReleaseVersion.next_tag_name(previous_tag: '21.12-8', config: config)).to eq('22.01-0')
      end
    end

    it 'month increment' do
      Timecop.freeze(Time.new(2022, 10, 1)) do
        expect(ReleaseDrafter::ReleaseVersion.next_tag_name(previous_tag: '22.09-5', config: config)).to eq('22.10-0')
      end
    end

    it 'micro increment' do
      Timecop.freeze(Time.new(2022, 1, 1)) do
        expect(ReleaseDrafter::ReleaseVersion.next_tag_name(previous_tag: '22.01-0', config: config)).to eq('22.01-1')
      end
    end
  end
end
