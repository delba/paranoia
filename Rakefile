require 'bundler'
require 'rake/clean'
require 'rake/testtask'

Bundler::GemHelper.install_tasks

Rake::TestTask.new do |task|
  task.pattern = "test/*_test.rb"
end

CLOBBER.include 'tmp'

task default: [:test]

task(:test).enhance do
  task(:clobber).invoke
end
