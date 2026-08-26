# © 2026 aiaiaiai · aiaiaiai.org

require "rake/testtask"

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end

desc "Run all deterministic repository checks"
task :check do
  %w[check_architecture check_contract check_copyright].each do |script|
    ruby File.expand_path("script/#{script}", __dir__)
  end
end

task default: %i[test check]
