#
# <copyright
# notice="lm-source-program"
# pids="5725-P60"
# years="2013,2014"
# crc="3568777996" >
# Licensed Materials - Property of IBM
#
# 5725-P60
#
# (C) Copyright IBM Corp. 2014
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
# </copyright>

require 'bundler'
require 'bundler/gem_tasks'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc 'Run RuboCop on the lib/mqlight directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = ['mqlight.gemspec', 'lib/mqlight.rb', 'lib/mqlight/*.rb',
                   'Rakefile', 'spec/spec_helper.rb', 'spec/mqlight/*.rb']
  # don't abort rake on failure
  task.fail_on_error = false
end

require 'rake/extensiontask'
Rake::ExtensionTask.new('cproton')

require 'rubygems'
require 'rubygems/package_task'
gemspec = Gem::Specification.load('mqlight.gemspec')
Gem::PackageTask.new(gemspec) do |pkg|
  pkg.package_dir = ENV['BPWD'] || 'build'
  begin
    Dir.mkdir(pkg.package_dir)
  rescue
    nil
  end
end

task default: [:spec]
task test: [:spec]

# TODO: enable RuboCop by default once violations are fixed
# task default: [:spec, :rubocop]
# task test: [:spec, :rubocop]
