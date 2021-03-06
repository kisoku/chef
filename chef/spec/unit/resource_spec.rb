#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2008-2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

class ResourceTestHarness < Chef::Resource
  provider_base Chef::Provider::Package
end

describe Chef::Resource do
  before(:each) do
    @cookbook_repo_path =  File.join(CHEF_SPEC_DATA, 'cookbooks')
    @cookbook_collection = Chef::CookbookCollection.new(Chef::CookbookLoader.new(@cookbook_repo_path))
    @node = Chef::Node.new
    @run_context = Chef::RunContext.new(@node, @cookbook_collection)
    @resource = Chef::Resource.new("funk", @run_context)
  end

  describe "load_prior_resource" do
    before(:each) do
      @prior_resource = Chef::Resource.new("funk")
      @prior_resource.supports(:funky => true)
      @prior_resource.source_line
      @prior_resource.allowed_actions << :funkytown
      @prior_resource.action(:funkytown)
      @resource.allowed_actions << :funkytown
      @run_context.resource_collection << @prior_resource
    end

    it "should load the attributes of a prior resource" do
      @resource.load_prior_resource
      @resource.supports.should == { :funky => true }
    end

    it "should not inherit the action from the prior resource" do
      @resource.load_prior_resource
      @resource.action.should_not == @prior_resource.action
    end
  end

  describe "name" do
    it "should have a name" do
      @resource.name.should eql("funk")
    end

    it "should let you set a new name" do
      @resource.name "monkey"
      @resource.name.should eql("monkey")
    end

    it "should not be valid without a name" do
      lambda { @resource.name false }.should raise_error(ArgumentError)
    end

    it "should always have a string for name" do
      lambda { @resource.name Hash.new }.should raise_error(ArgumentError)
    end
  end

  describe "noop" do
    it "should accept true or false for noop" do
      lambda { @resource.noop true }.should_not raise_error(ArgumentError)
      lambda { @resource.noop false }.should_not raise_error(ArgumentError)
      lambda { @resource.noop "eat it" }.should raise_error(ArgumentError)
    end
  end

  describe "notifies" do
    it "should make notified resources appear in the actions hash" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      @resource.notifies :reload, @run_context.resource_collection.find(:zen_master => "coffee")
      @resource.delayed_notifications.detect{|e| e.resource.name == "coffee" && e.action == :reload}.should_not be_nil
    end

    it "should make notified resources be capable of acting immediately" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      @resource.notifies :reload, @run_context.resource_collection.find(:zen_master => "coffee"), :immediate
      @resource.immediate_notifications.detect{|e| e.resource.name == "coffee" && e.action == :reload}.should_not be_nil
    end

    it "should raise an exception if told to act in other than :delay or :immediate(ly)" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      lambda {
        @resource.notifies :reload, @run_context.resource_collection.find(:zen_master => "coffee"), :someday
      }.should raise_error(ArgumentError)
    end

    it "should allow multiple notified resources appear in the actions hash" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      @resource.notifies :reload, @run_context.resource_collection.find(:zen_master => "coffee")
      @resource.delayed_notifications.detect{|e| e.resource.name == "coffee" && e.action == :reload}.should_not be_nil

      @run_context.resource_collection << Chef::Resource::ZenMaster.new("beans")
      @resource.notifies :reload, @run_context.resource_collection.find(:zen_master => "beans")
      @resource.delayed_notifications.detect{|e| e.resource.name == "beans" && e.action == :reload}.should_not be_nil
    end

    it "creates a notification for a resource that is not yet in the resource collection" do
      @resource.notifies(:restart, :service => 'apache')
      expected_notification = Chef::Resource::Notification.new({:service => "apache"}, :restart, @resource)
      @resource.delayed_notifications.should include(expected_notification)
    end

    it "notifies another resource immediately" do
      @resource.notifies_immediately(:restart, :service => 'apache')
      expected_notification = Chef::Resource::Notification.new({:service => "apache"}, :restart, @resource)
      @resource.immediate_notifications.should include(expected_notification)
    end

    it "notifies a resource to take action at the end of the chef run" do
      @resource.notifies_delayed(:restart, :service => "apache")
      expected_notification = Chef::Resource::Notification.new({:service => "apache"}, :restart, @resource)
      @resource.delayed_notifications.should include(expected_notification)
    end
  end

  describe "subscribes" do
    it "should make resources appear in the actions hash of subscribed nodes" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      zr = @run_context.resource_collection.find(:zen_master => "coffee")
      @resource.subscribes :reload, zr
      zr.delayed_notifications.detect{|e| e.resource.name == "funk" && e.action == :reload}.should_not be_nil
    end

    it "should make resources appear in the actions hash of subscribed nodes" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      zr = @run_context.resource_collection.find(:zen_master => "coffee")
      @resource.subscribes :reload, zr
      zr.delayed_notifications.detect{|e| e.resource.name == @resource.name && e.action == :reload}.should_not be_nil

      @run_context.resource_collection << Chef::Resource::ZenMaster.new("bean")
      zrb = @run_context.resource_collection.find(:zen_master => "bean")
      zrb.subscribes :reload, zr
      zr.delayed_notifications.detect{|e| e.resource.name == @resource.name && e.action == :reload}.should_not be_nil
    end

    it "should make subscribed resources be capable of acting immediately" do
      @run_context.resource_collection << Chef::Resource::ZenMaster.new("coffee")
      zr = @run_context.resource_collection.find(:zen_master => "coffee")
      @resource.subscribes :reload, zr, :immediately
      zr.immediate_notifications.detect{|e| e.resource.name == @resource.name && e.action == :reload}.should_not be_nil
    end
  end

  describe "to_s" do
    it "should become a string like resource_name[name]" do
      zm = Chef::Resource::ZenMaster.new("coffee")
      zm.to_s.should eql("zen_master[coffee]")
    end
  end

  describe "is" do
    it "should return the arguments passed with 'is'" do
      zm = Chef::Resource::ZenMaster.new("coffee")
      zm.is("one", "two", "three").should == %w|one two three|
    end

    it "should allow arguments preceeded by is to methods" do
      @resource.noop(@resource.is(true))
      @resource.noop.should eql(true)
    end
  end

  describe "to_json" do
    it "should serialize to json" do
      json = @resource.to_json
      json.should =~ /json_class/
      json.should =~ /instance_vars/
    end
  end

  describe "to_hash" do
    it "should convert to a hash" do
      hash = @resource.to_hash
      expected_keys = [ :allowed_actions, :params, :provider, :updated,
        :updated_by_last_action, :before, :supports, :delayed_notifications,
        :immediate_notifications, :noop, :ignore_failure, :name, :source_line,
        :action, :retries, :retry_delay ]
      (hash.keys - expected_keys).should == []
      (expected_keys - hash.keys).should == []
      hash[:name].should eql("funk")
    end
  end

  describe "self.json_create" do
    it "should deserialize itself from json" do
      json = @resource.to_json
      serialized_node = Chef::JSONCompat.from_json(json)
      serialized_node.should be_a_kind_of(Chef::Resource)
      serialized_node.name.should eql(@resource.name)
    end
  end

  describe "supports" do
    it "should allow you to set what features this resource supports" do
      support_hash = { :one => :two }
      @resource.supports(support_hash)
      @resource.supports.should eql(support_hash)
    end

    it "should return the current value of supports" do
      @resource.supports.should == {}
    end
  end

  describe "ignore_failure" do
    it "should default to throwing an error if a provider fails for a resource" do
      @resource.ignore_failure.should == false
    end

    it "should allow you to set whether a provider should throw exceptions with ignore_failure" do
      @resource.ignore_failure(true)
      @resource.ignore_failure.should == true
    end

    it "should allow you to epic_fail" do
      @resource.epic_fail(true)
      @resource.epic_fail.should == true
    end
  end

  describe "retries" do
    it "should default to not retrying if a provider fails for a resource" do
      @resource.retries.should == 0
    end

    it "should allow you to set how many retries a provider should attempt after a failure" do
      @resource.retries(2)
      @resource.retries.should == 2
    end

    it "should default to a retry delay of 2 seconds" do
      @resource.retry_delay.should == 2
    end

    it "should allow you to set the retry delay" do
      @resource.retry_delay(10)
      @resource.retry_delay.should == 10
    end
  end

  describe "setting the base provider class for the resource" do

    it "defaults to Chef::Provider for the base class" do
      Chef::Resource.provider_base.should == Chef::Provider
    end

    it "allows the base provider to be overriden by a " do
      ResourceTestHarness.provider_base.should == Chef::Provider::Package
    end

  end

  it "supports accessing the node via the @node instance variable [DEPRECATED]" do
    @resource.instance_variable_get(:@node).should == @node
  end

  it "runs an action by finding its provider, loading the current resource and then running the action" do
    pending
  end

  describe "when updated by a provider" do
    before do
      @resource.updated_by_last_action(true)
    end

    it "records that it was updated" do
      @resource.should be_updated
    end

    it "records that the last action updated the resource" do
      @resource.should be_updated_by_last_action
    end

    describe "and then run again without being updated" do
      before do
        @resource.updated_by_last_action(false)
      end

      it "reports that it is updated" do
        @resource.should be_updated
      end

      it "reports that it was not updated by the last action" do
        @resource.should_not be_updated_by_last_action
      end

    end

  end

  describe "when invoking its action" do

    before do
      @resource = Chef::Resource.new("provided", @run_context)
      @resource.provider = Chef::Provider::SnakeOil
      @node[:platform] = "fubuntu"
      @node[:platform_version] = '10.04'
    end

    it "does not run only_if if no only_if command is given" do
      @resource.not_if.clear
      @resource.run_action(:purr)
    end

    it "runs runs an only_if when one is given" do
      snitch_variable = nil
      @resource.only_if { snitch_variable = true }
      @resource.only_if.first.positivity.should == :only_if
      #Chef::Mixin::Command.should_receive(:only_if).with(true, {}).and_return(false)
      @resource.run_action(:purr)
      snitch_variable.should be_true
    end

    it "runs multiple only_if conditionals" do
      snitch_var1, snitch_var2 = nil, nil
      @resource.only_if { snitch_var1 = 1 }
      @resource.only_if { snitch_var2 = 2 }
      @resource.run_action(:purr)
      snitch_var1.should == 1
      snitch_var2.should == 2
    end

    it "accepts command options for only_if conditionals" do
      Chef::Resource::Conditional.any_instance.should_receive(:evaluate_command).at_least(1).times
      @resource.only_if("true", :cwd => '/tmp')
      @resource.only_if.first.command_opts.should == {:cwd => '/tmp'}
      @resource.run_action(:purr)
    end

    it "runs not_if as a command when it is a string" do
      Chef::Resource::Conditional.any_instance.should_receive(:evaluate_command).at_least(1).times
      @resource.not_if "pwd"
      @resource.run_action(:purr)
    end

    it "runs not_if as a block when it is a ruby block" do
      Chef::Resource::Conditional.any_instance.should_receive(:evaluate_block).at_least(1).times
      @resource.not_if { puts 'foo' }
      @resource.run_action(:purr)
    end

    it "does not run not_if if no not_if command is given" do
      @resource.run_action(:purr)
    end

    it "accepts command options for not_if conditionals" do
      @resource.not_if("pwd" , :cwd => '/tmp')
      @resource.not_if.first.command_opts.should == {:cwd => '/tmp'}
    end

    it "accepts multiple not_if conditionals" do
      snitch_var1, snitch_var2 = true, true
      @resource.not_if {snitch_var1 = nil}
      @resource.not_if {snitch_var2 = false}
      @resource.run_action(:purr)
      snitch_var1.should be_nil
      snitch_var2.should be_false
    end

  end

  describe "building the platform map" do

    it 'adds mappings for a single platform' do
      klz = Class.new(Chef::Resource)
      Chef::Resource.platform_map.should_receive(:set).with(
        :platform => :autobots, :short_name => :dinobot, :resource => klz
      )
      klz.provides :dinobot, :on_platforms => ['autobots']
    end

    it 'adds mappings for multiple platforms' do
      klz = Class.new(Chef::Resource)
      Chef::Resource.platform_map.should_receive(:set).twice
      klz.provides :energy, :on_platforms => ['autobots','decepticons']
    end

    it 'adds mappings for all platforms' do
      klz = Class.new(Chef::Resource)
      Chef::Resource.platform_map.should_receive(:set).with(
        :short_name => :tape_deck, :resource => klz
      )
      klz.provides :tape_deck
    end

  end

  describe "lookups from the platform map" do

    before(:each) do
      @node = Chef::Node.new
      @node.name("bumblebee")
      @node.platform("autobots")
      @node.platform_version("6.1")
      Object.const_set('Soundwave', Class.new(Chef::Resource))
      Object.const_set('Grimlock', Class.new(Chef::Resource){ provides :dinobot, :on_platforms => ['autobots'] })
    end

    after(:each) do
      Object.send(:remove_const, :Soundwave)
      Object.send(:remove_const, :Grimlock)
    end

    describe "resource_for_platform" do
      it 'return a resource by short_name and platform' do
        Chef::Resource.resource_for_platform(:dinobot,'autobots','6.1').should eql(Grimlock)
      end
      it "returns a resource by short_name if nothing else matches" do
        Chef::Resource.resource_for_node(:soundwave, @node).should eql(Soundwave)
      end
    end

    describe "resource_for_node" do
      it "returns a resource by short_name and node" do
        Chef::Resource.resource_for_node(:dinobot, @node).should eql(Grimlock)
      end
      it "returns a resource by short_name if nothing else matches" do
        Chef::Resource.resource_for_node(:soundwave, @node).should eql(Soundwave)
      end
    end

  end
end

describe Chef::Resource::Notification do
  before do
    @notification = Chef::Resource::Notification.new(:service_apache, :restart, :template_httpd_conf)
  end

  it "has a resource to be notified" do
    @notification.resource.should == :service_apache
  end

  it "has an action to take on the service" do
    @notification.action.should == :restart
  end

  it "has a notifying resource" do
    @notification.notifying_resource.should == :template_httpd_conf
  end

  it "is a duplicate of another notification with the same target resource and action" do
    other = Chef::Resource::Notification.new(:service_apache, :restart, :sync_web_app_code)
    @notification.duplicates?(other).should be_true
  end

  it "is not a duplicate of another notification if the actions differ" do
    other = Chef::Resource::Notification.new(:service_apache, :enable, :install_apache)
    @notification.duplicates?(other).should be_false
  end

  it "is not a duplicate of another notification if the target resources differ" do
    other = Chef::Resource::Notification.new(:service_sshd, :restart, :template_httpd_conf)
    @notification.duplicates?(other).should be_false
  end

  it "raises an ArgumentError if you try to check a non-ducktype object for duplication" do
    lambda {@notification.duplicates?(:not_a_notification)}.should raise_error(ArgumentError)
  end

  it "takes no action to resolve a resource reference that doesn't need to be resolved" do
    @keyboard_cat = Chef::Resource::Cat.new("keyboard_cat")
    @notification.resource = @keyboard_cat
    @resource_collection = Chef::ResourceCollection.new
    # would raise an error since the resource is not in the collection
    @notification.resolve_resource_reference(@resource_collection)
    @notification.resource.should == @keyboard_cat
  end

  it "resolves a lazy reference to a resource" do
    @notification.resource = {:cat => "keyboard_cat"}
    @keyboard_cat = Chef::Resource::Cat.new("keyboard_cat")
    @resource_collection = Chef::ResourceCollection.new
    @resource_collection << @keyboard_cat
    @notification.resolve_resource_reference(@resource_collection)
    @notification.resource.should == @keyboard_cat
  end

end
