# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UmbScraper do
  let(:scraper) { described_class.new }
  let(:discipline) { create(:discipline, name: 'Dreiband') }

  describe '#initialize' do
    it 'creates or finds UMB source' do
      expect { scraper }.to change(InternationalSource, :count).by(1)
      
      source = scraper.umb_source
      expect(source.name).to eq('Union Mondiale de Billard')
      expect(source.source_type).to eq('umb')
      expect(source.base_url).to eq(UmbScraper::BASE_URL)
    end

    it 'reuses existing UMB source' do
      source1 = described_class.new.umb_source
      source2 = described_class.new.umb_source
      
      expect(source1.id).to eq(source2.id)
    end
  end

  describe '#scrape_future_tournaments' do
    let(:html_response) do
      File.read(Rails.root.join('spec', 'fixtures', 'umb_future_tournaments.html'))
    end

    before do
      allow(scraper).to receive(:fetch_url).and_return(html_response)
      discipline # ensure discipline exists
    end

    it 'fetches and parses tournaments from UMB' do
      expect(scraper).to receive(:fetch_url).with(UmbScraper::FUTURE_TOURNAMENTS_URL)
      
      count = scraper.scrape_future_tournaments
      
      # With date parsing implemented, we should get tournaments
      expect(count).to be > 0
    end

    it 'creates correct number of tournaments' do
      expect {
        scraper.scrape_future_tournaments
      }.to change(InternationalTournament, :count).by_at_least(10)
    end

    it 'marks source as scraped' do
      scraper.scrape_future_tournaments
      
      expect(scraper.umb_source.last_scraped_at).to be_present
    end

    it 'saves tournaments with correct data' do
      scraper.scrape_future_tournaments
      
      # Check a specific tournament
      wc = InternationalTournament.find_by(name: 'World Championship National Teams 3-Cushion')
      expect(wc).to be_present
      expect(wc.location).to eq('Viersen, Germany')
      expect(wc.start_date).to eq(Date.new(2026, 2, 26))
      expect(wc.end_date).to eq(Date.new(2026, 3, 1))
      expect(wc.tournament_type).to eq('world_championship')
      expect(wc.discipline).to eq(discipline)
      expect(wc.international_source).to eq(scraper.umb_source)
    end

    it 'correctly identifies tournament types' do
      scraper.scrape_future_tournaments
      
      expect(InternationalTournament.where(tournament_type: 'world_championship').count).to be > 0
      expect(InternationalTournament.where(tournament_type: 'world_cup').count).to be > 0
      expect(InternationalTournament.where(tournament_type: 'invitation').count).to be > 0
    end

    it 'handles year-spanning dates' do
      scraper.scrape_future_tournaments
      
      # "Feb 26 - Mar 1, 2026" should span into March
      wc = InternationalTournament.find_by(name: 'World Championship National Teams 3-Cushion')
      expect(wc.start_date.month).to eq(2)
      expect(wc.end_date.month).to eq(3)
    end

    context 'when fetch fails' do
      before do
        allow(scraper).to receive(:fetch_url).and_return(nil)
      end

      it 'returns 0' do
        expect(scraper.scrape_future_tournaments).to eq(0)
      end

      it 'still marks source as scraped' do
        scraper.scrape_future_tournaments
        expect(scraper.umb_source.last_scraped_at).to be_present
      end
    end

    context 'when tournament already exists' do
      let!(:existing_tournament) do
        InternationalTournament.create!(
          name: 'World Championship National Teams 3-Cushion',
          start_date: Date.new(2026, 2, 26),
          end_date: Date.new(2026, 3, 1),
          location: 'Old Location',
          discipline: discipline,
          tournament_type: 'world_championship',
          international_source: scraper.umb_source
        )
      end

      it 'updates existing tournament instead of creating duplicate' do
        expect {
          scraper.scrape_future_tournaments
        }.not_to change(InternationalTournament, :count)
      end

      it 'updates location' do
        scraper.scrape_future_tournaments
        existing_tournament.reload
        expect(existing_tournament.location).to eq('Viersen, Germany')
      end
    end
  end

  describe 'private methods' do
    describe '#parse_date_range' do
      it 'parses "18-21 Dec 2025"' do
        result = scraper.send(:parse_date_range, '18-21 Dec 2025')
        expect(result[:start_date]).to eq(Date.new(2025, 12, 18))
        expect(result[:end_date]).to eq(Date.new(2025, 12, 21))
      end

      it 'parses "December 18-21, 2025"' do
        result = scraper.send(:parse_date_range, 'December 18-21, 2025')
        expect(result[:start_date]).to eq(Date.new(2025, 12, 18))
        expect(result[:end_date]).to eq(Date.new(2025, 12, 21))
      end

      it 'parses "Feb 26 - Mar 1, 2026"' do
        result = scraper.send(:parse_date_range, 'Feb 26 - Mar 1, 2026')
        expect(result[:start_date]).to eq(Date.new(2026, 2, 26))
        expect(result[:end_date]).to eq(Date.new(2026, 3, 1))
      end

      it 'parses "September 15-27, 2026"' do
        result = scraper.send(:parse_date_range, 'September 15-27, 2026')
        expect(result[:start_date]).to eq(Date.new(2026, 9, 15))
        expect(result[:end_date]).to eq(Date.new(2026, 9, 27))
      end

      it 'handles year wrap "Dec 28 - Jan 3, 2025"' do
        result = scraper.send(:parse_date_range, 'Dec 28 - Jan 3, 2025')
        expect(result[:start_date]).to eq(Date.new(2025, 12, 28))
        expect(result[:end_date]).to eq(Date.new(2026, 1, 3))
      end

      it 'returns nil for unparseable dates' do
        result = scraper.send(:parse_date_range, 'Invalid Date')
        expect(result[:start_date]).to be_nil
        expect(result[:end_date]).to be_nil
      end

      it 'returns nil for blank dates' do
        result = scraper.send(:parse_date_range, '')
        expect(result[:start_date]).to be_nil
        expect(result[:end_date]).to be_nil
      end
    end

    describe '#parse_month_name' do
      it 'parses full month names' do
        expect(scraper.send(:parse_month_name, 'January')).to eq(1)
        expect(scraper.send(:parse_month_name, 'December')).to eq(12)
      end

      it 'parses abbreviated month names' do
        expect(scraper.send(:parse_month_name, 'Jan')).to eq(1)
        expect(scraper.send(:parse_month_name, 'Dec')).to eq(12)
        expect(scraper.send(:parse_month_name, 'Sept')).to eq(9)
      end

      it 'is case insensitive' do
        expect(scraper.send(:parse_month_name, 'JANUARY')).to eq(1)
        expect(scraper.send(:parse_month_name, 'january')).to eq(1)
      end

      it 'returns nil for invalid names' do
        expect(scraper.send(:parse_month_name, 'Foo')).to be_nil
        expect(scraper.send(:parse_month_name, '')).to be_nil
      end
    end

    describe '#determine_tournament_type' do
      it 'identifies world championships' do
        type = scraper.send(:determine_tournament_type, 'World Championship 3-Cushion')
        expect(type).to eq('world_championship')
      end

      it 'identifies world cups' do
        type = scraper.send(:determine_tournament_type, 'World Cup 3-Cushion')
        expect(type).to eq('world_cup')
      end

      it 'identifies world masters' do
        type = scraper.send(:determine_tournament_type, 'UMB 3-Cushion World Masters')
        expect(type).to eq('invitation')
      end

      it 'identifies european championships' do
        type = scraper.send(:determine_tournament_type, 'European Championship')
        expect(type).to eq('european_championship')
      end

      it 'defaults to other' do
        type = scraper.send(:determine_tournament_type, 'Blois Challenge')
        expect(type).to eq('other')
      end
    end

    describe '#find_discipline' do
      before do
        discipline # ensure discipline exists
      end

      it 'finds 3-cushion discipline' do
        d = scraper.send(:find_discipline, '3-Cushion')
        expect(d).to eq(discipline)
      end

      it 'finds 3 cushion discipline (with space)' do
        d = scraper.send(:find_discipline, '3 Cushion')
        expect(d).to eq(discipline)
      end

      it 'returns nil for blank name' do
        d = scraper.send(:find_discipline, '')
        expect(d).to be_nil
      end
    end
  end

  describe 'integration' do
    it 'can be run as background job' do
      expect {
        ScrapeUmbJob.perform_now
      }.not_to raise_error
    end
  end
end
