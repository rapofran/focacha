ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'bundler'

Bundler.require :default, :test

begin
  require 'focacha'
rescue LoadError
  require File.join(File.dirname(__FILE__), '..', 'focacha')
end

class MiniTest::Spec
  after :each do
    Mongoid.purge!
  end
end
