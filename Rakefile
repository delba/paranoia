require 'bundler'
require 'rake/testtask'
Bundler::GemHelper.install_tasks

task default: [:test]

Rake::TestTask.new do |task|
  task.pattern = "test/*_test.rb"
end
