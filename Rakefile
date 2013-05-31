require 'bundler'

Bundler::GemHelper.install_tasks

task default: [:test]

task(:test) do
  begin
    ruby "test/*_test.rb"
  ensure
    task(:clean).invoke
  end
end

task(:clean) do
  rm_r "tmp"
end
