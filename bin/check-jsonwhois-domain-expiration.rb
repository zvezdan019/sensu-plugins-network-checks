#!/usr/bin/env ruby
# encoding: utf-8
#
#   check-jsonwhois-domain-expiration
#
# DESCRIPTION:
#   This plugin checks domain expiration dates using the https://jsonwhois.com API
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Any
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   ./check-jsonwhois-domain-expiration.rb -a [YOUR API KEY] -d foo.com,bar.com
#   JSONWhoisDomainExpirationCheck WARNING: foo.com: 30 days
#
# LICENSE:
#   Copyright 2015 Matt Greensmith (mgreensmith@cozy.co) - Cozy Services Ltd.
#   Based on check-whois-domain-expiration-multi, Copyright 2015 Tim Smith (tim@cozy.co) - Cozy Services Ltd.
#   Based on check-whois-domain-expiration, Copyright 2015 michael j talarczyk <mjt@mijit.com>
#    and contributors.
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'

require 'net/http'
require 'json'
require 'date'

#
# Check Whois domain expiration
#
class JSONWhoisDomainExpirationCheck < Sensu::Plugin::Check::CLI
  option :domain,
         short: '-d DOMAINS',
         long: '--domains DOMAIN',
         required: true,
         description: 'Comma-separated list of domains to check.'

  option :apikey,
         short: '-a APIKEY',
         long: '--apikey APIKEY',
         required: true,
         description: 'API key for jsonwhois.com'

  option :warning,
         short: '-w DAYS',
         long: '--warn DAYS',
         default: 30,
         description: 'Warn if a domain expires in fewer than DAYS days'

  option :critical,
         short: '-c DAYS',
         long: '--critical DAYS',
         default: 7,
         description: 'Critical if a domain expires in fewer than DAYS days'

  option :help,
         short: '-h',
         long: '--help',
         description: 'Show this message',
         on: :tail,
         boolean: true,
         show_options: true,
         exit: 0

  # Split the provided domain list and perform whois lookups on each
  #
  # @return [Hash] a hash of severity_level -> domain -> days until expiry
  def expiration_results
    domains = config[:domain].split(',')
    warning_days = config[:warning].to_i
    critical_days = config[:critical].to_i
    results = {}
    results['critical'] = {}
    results['warning'] = {}
    results['ok'] = {}

    domains.each do |domain|
      domain_result = (get_domain_expiration(domain) - DateTime.now).to_i
      if domain_result <= critical_days
        results['critical'][domain] = domain_result
      elsif domain_result <= warning_days
        results['warning'][domain] = domain_result
      else
        results['ok'] = domain_result
      end
    end
    results
  end

  # Fetch whois data from the JSONWhois API and return the "expires_on" date
  #
  # @param domain [String] the domain to fetch from JSONWhois
  # @return [DateTime] the expiration date for the domain
  def get_domain_expiration(domain)
    uri = URI('https://jsonwhois.com/api/v1/whois')
    uri.query = URI.encode_www_form(domain: domain)
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Token token=#{config[:apikey]}"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(req)
    end

    DateTime.parse(JSON.parse(res.body)['expires_on'])
  end

  def run
    status = expiration_results
    if !status['critical'].empty?
      critical status['critical'].map { |u, v| "#{u} days left:#{v}" }.join(',')
    elsif !status['warning'].empty?
      warning status['warning'].map { |u, v| "#{u} days left:#{v}" }.join(',')
    else
      ok 'No domains expire in the near term'
    end
  end
end
