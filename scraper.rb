#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    noko.css('#Kilder').xpath('.//following::*').remove
    noko.xpath('//div[@id="mw-content-text"]//ul/li[.//a]').map do |li|
      data = fragment(li => MemberItem).to_h
      data[:party_id] = parties.find { |p| p[:shortname] == data[:party] }[:id] rescue binding.pry
      data
    end
  end

  private

  def parties
    @parties ||= party_rows.map { |row| fragment(row => PartyRow).to_h }
  end

  def party_table
    noko.xpath('//table[.//th[contains(.,"Partinavn")]]')
  end

  def party_rows
    party_table.xpath('.//tr[td]')
  end
end

class MemberItem < Scraped::HTML
  field :id do
    noko.css('a/@wikidata').map(&:text).first rescue binding.pry
  end

  field :name do
    noko.css('a').map(&:text).map(&:tidy).first
  end

  field :party do
    noko.text[/\(([A-Z]{1,3})\)/, 1]
  end
end

class PartyRow < Scraped::HTML
  field :shortname do
    tds[0].text.tidy
  end

  field :id do
    tds[1].css('a/@wikidata').map(&:text).first rescue binding.pry
  end

  field :name do
    tds[1].css('a').map(&:text).map(&:tidy).first
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_2015'
Scraped::Scraper.new(url => MembersPage).store(:members)
