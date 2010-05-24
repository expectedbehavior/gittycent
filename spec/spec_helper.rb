require 'rubygems'
require 'spec'
require 'fakeweb'
FakeWeb.allow_net_connect = false

$: << File.join(File.dirname(__FILE__), '..', 'lib')
require 'gittycent'

Spec::Runner.configure do |config|
  
end