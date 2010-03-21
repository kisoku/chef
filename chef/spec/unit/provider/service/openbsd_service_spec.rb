#
# Author:: Mathieu Sauve-Frankel <msf@kisoku.net>
# Copyright:: Copyright (c) 2009 Mathieu Sauve-Frankel
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

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "spec_helper"))

describe Chef::Provider::Service::Openbsd, "load_current_resource" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @node.stub!(:[]).with(:command).and_return({:ps => "ps -ax"})

    @new_resource = mock("Chef::Resource::Service",
      :null_object => true,
      :name => "ntpd",
      :service_name => "ntpd",
      :running => false,
      :enabled => false,
      :options => {
        :enable_variable => "ntpd_flags",
        :enable_flags => "-s"
      }
    )
    @new_resource.stub!(:pattern).and_return("ntpd")
    @new_resource.stub!(:supports).and_return({:status => false})
    @new_resource.stub!(:status_command).and_return(false)

    @current_resource = mock("Chef::Resource::Service",
      :null_object => true,
      :name => "ntpd",
      :service_name => "ntpd",
      :running => false,
      :enabled => false
    )

    @provider = Chef::Provider::Service::Openbsd.new(@node, @new_resource)
    Chef::Resource::Service.stub!(:new).and_return(@current_resource)

    @status = mock("Status", :exitstatus => 0)
    @provider.stub!(:popen4).and_return(@status)
    @stdin = mock("STDIN", :null_object => true)
    @stdout = mock("STDOUT", :null_object => true)
    @stdout.stub!(:each).and_yield("9413  ??  Ss     0:02.51 syslogd: [priv] (syslogd)").
                         and_yield("3207 ??  Is     0:00.14 /usr/sbin/sshd").
                         and_yield("7685  ??  Ss     0:17.53 sendmail: accepting connections (sendmail)")
    @stderr = mock("STDERR", :null_object => true)
    @pid = mock("PID", :null_object => true)

    ::File.stub!(:exists?).and_return(false)
    ::File.stub!(:exists?).with("/etc/rc.conf.local").and_return(true)

    @lines = mock("lines")
    @lines.stub!(:each_line).and_yield("ntpd_flags=\"-s\"").
                        and_yield("httpd_flags=\"-DSSL\"")
    ::File.stub!(:open).and_return(@lines)

  end
  
  it "should create a current resource with the name of the new resource" do
    Chef::Resource::Service.should_receive(:new).and_return(@current_resource)
    @provider.load_current_resource
  end

  it "should set the current resources service name to the new resources service name" do
    @current_resource.should_receive(:service_name).with(@new_resource.service_name)
    @provider.load_current_resource
  end

  it "should set running to false if the node has a nil ps attribute" do
    @node.stub!(:[]).with(:command).and_return({:ps => nil})
    lambda { @provider.load_current_resource }.should raise_error(Chef::Exceptions::Service)
  end

  it "should set running to false if the node has an empty ps attribute" do
    @node.stub!(:[]).with(:command).and_return(:ps => "")
    lambda { @provider.load_current_resource }.should raise_error(Chef::Exceptions::Service)
  end

  describe "when we have a 'ps' attribute" do
    before do
      @node.stub!(:[]).with(:command).and_return({:ps => "ps -ax"})
    end

    it "should popen4 the node's ps command" do
      @provider.should_receive(:popen4).with(@node[:command][:ps]).and_return(@status)
      @provider.load_current_resource
    end

    it "should read stdout of the ps command" do
      @provider.stub!(:popen4).and_yield(@pid, @stdin, @stdout, @stderr).and_return(@status)
      @stdout.should_receive(:each_line).and_return(true)
      @provider.load_current_resource
    end

    it "should set running to true if the regex matches the output" do
      @stdout.stub!(:each_line).
        and_yield("555  ??  Ss     0:05.16 cron").
        and_yield("15926 ??  Is      0:00.03 ntpd: [priv] (ntpd)").
        and_yield("26848 ??  I       0:00.71 ntpd: ntp engine (ntpd)").
        and_yield("14011 ??  I       0:00.01 ntpd: dns engine (ntpd)")
      
      @provider.stub!(:popen4).and_yield(@pid, @stdin, @stdout, @stderr).and_return(@status)
      @current_resource.should_receive(:running).with(true)
      @provider.load_current_resource 
    end

    it "should set running to false if the regex doesn't match" do
      @provider.stub!(:popen4).and_yield(@pid, @stdin, @stdout, @stderr).and_return(@status)
      @current_resource.should_receive(:running).with(false)
      @provider.load_current_resource
    end

    it "should raise an exception if ps fails" do
      @status.stub!(:exitstatus).and_return(-1)
      lambda { @provider.load_current_resource }.should raise_error(Chef::Exceptions::Service)
    end
  end

  it "should return the current resource" do
    @provider.load_current_resource.should eql(@current_resource)
  end

end

describe Chef::Provider::Service::Openbsd, "enable_service" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Service",
      :null_object => true,
      :name => "ntpd",
      :service_name => "ntpd",
      :running => false,
      :enabled => false,
      :options => {
        :enable_variable => "ntpd_flags",
        :enable_flags => "-s"
      }
    )

    @current_resource = mock("Chef::Resource::Service",
      :null_object => true,
      :name => "ntpd",
      :service_name => "ntpd",
      :running => false,
      :enabled => false,
      :options => {
        :enable_variable => "ntpd_flags",
        :enable_flags => "-s"
      }
    )

    @provider = Chef::Provider::Service::Openbsd.new(@node, @new_resource)
    Chef::Resource::Service.stub!(:new).and_return(@current_resource)
    @provider.current_resource = @current_resource
  end

  it "should should enable the service if it is not enabled" do
    @current_resource.stub!(:enabled).and_return(false)

    @provider.stub!(:enable_variable).and_return("ntpd_flags")
    @provider.stub!(:enable_flags).and_return("-s")
    @provider.should_receive(:read_rc_conf_local).and_return([ "foo", "ntpd_flags=\"NO\"", "bar" ])
    @provider.should_receive(:write_rc_conf_local).with(["foo", "bar", "ntpd_flags=\"-s\""])
    @provider.enable_service()
  end
  
  it "should enable the service if it is not enabled and not already specified in the rc.conf file" do
    @current_resource.stub!(:enabled).and_return(false)
    @provider.should_receive(:read_rc_conf_local).and_return([ "foo", "bar" ])
    @provider.should_receive(:write_rc_conf_local).with(["foo", "bar", "ntpd_flags=\"-s\""])
    @provider.enable_service()
  end

  it "should not enable the service if it is already enabled" do
    @current_resource.stub!(:enabled).and_return(true)
    @provider.should_not_receive(:write_rc_conf_local)
    @provider.enable_service
  end
end

describe Chef::Provider::Service::Openbsd, "disable_service" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Service",
      :null_object => true,
      :name => "ntpd",
      :service_name => "ntpd",
      :running => false,
      :enabled => false,
      :options => {
        :enable_variable => "ntpd_flags",
        :enable_flags => "-s"
      }
    )

    @current_resource = mock("Chef::Resource::Service",
      :null_object => true,
      :name => "ntpd",
      :service_name => "ntpd",
      :running => false,
      :enabled => false,
      :options => {
        :enable_variable => "ntpd_flags",
        :enable_flags => "-s"
      }
    )

    @provider = Chef::Provider::Service::Openbsd.new(@node, @new_resource)
    Chef::Resource::Service.stub!(:new).and_return(@current_resource)
    @provider.current_resource = @current_resource
  end

  it "should should disable the service if it is not disabled" do
    @current_resource.stub!(:enabled).and_return(true)
    @provider.should_receive(:read_rc_conf_local).and_return([ "foo", "ntpd_flags=\"-s\"", "bar" ])
    @provider.should_receive(:write_rc_conf_local).with(["foo", "bar", "ntpd_flags=\"NO\""])
    @provider.disable_service()
  end

  it "should not disable the service if it is already disabled" do
    @current_resource.stub!(:enabled).and_return(false)
    @provider.should_not_receive(:write_rc_conf_local)
    @provider.disable_service()
  end
end

