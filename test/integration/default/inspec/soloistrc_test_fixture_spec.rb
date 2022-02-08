# frozen_string_literal: true

describe directory('/var/chef/cache') do
  its('mode') { should eq 0777 }
  its('owner') { should eq 'root' }
  its('group') { should eq 'admin' }
end

describe directory('/Users/vagrant/.rvm') do
  its('mode') { should eq 0755 }
  its('owner') { should eq 'vagrant' }
  its('group') { should eq 'staff' }
end

defaults_settings = [
  { key: '/Users/vagrant/Library/Preferences/.GlobalPreferences com.apple.keyboard.fnState', value: 1},
  { key: '/Library/Preferences/com.apple.loginwindow showInputMenu', value: 1 },
  { key: 'com.apple.screensaver askForPasswordDelay', value: 0 },
  { key: 'com.apple.TimeMachine DoNotOfferNewDisksForBackup', value: 1 },
  { key: 'com.apple.dock autohide', value: 0 },
  { key: 'com.apple.Terminal Default\ Window\ Settings', value: 'Pro' }
]
defaults_settings.each do |s|
  describe command("defaults read #{s[:key]}") do
    its('stdout') { should match ("#{s[:value]}") }
  end
end

describe command('pmset -g') do
  its('stdout') { should match /^\s*displaysleep\s*0$/ }
  its('stdout') { should match /^\s*disksleep\s*0$/ }
  its('stdout') { should match /^\s*sleep\s*0\s*.*$/ }
end

pkgs = [ 'bash-completion',
  'lua',
  'ssh-copy-id',
  'mediainfo',
  'sleepwatcher',
  'lazydocker',
  'lsusb'
]

pkgs.each do |pkg|
  describe package(pkg) do
    it { should be_installed }
  end
end
