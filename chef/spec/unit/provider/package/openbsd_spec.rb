#
# Authors:: Mathieu Sauve-Frankel <msf@kisoku.net>
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

describe Chef::Provider::Package::Openbsd, "load_current_resource" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "bash",
      :package_name => "bash",
      :version => nil
    )
    @current_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "bash",
      :package_name => "bash",
      :version => nil
    )

    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)
    Chef::Resource::Package.stub!(:new).and_return(@current_resource)

    @provider.stub!(:candidate_version).and_return("4.0")
  end

  it "should create a current resource with the name of the new_resource" do
    Chef::Resource::Package.should_receive(:new).and_return(@current_resource)
    @provider.should_receive(:current_installed_version).and_return(nil)
    @provider.load_current_resource
  end

  it "should return a version if the package is installed" do
    @provider.should_receive(:current_installed_version).and_return("4.0")
    @current_resource.should_receive(:version).with("4.0").and_return(true)
    @provider.load_current_resource
  end

  it "should return nil if the package is not installed" do
    @provider.should_receive(:current_installed_version).and_return(nil)
    @current_resource.should_receive(:version).with(nil).and_return(true)
    @provider.load_current_resource
  end

  it "should return a candidate version if it exists" do
    @provider.should_receive(:current_installed_version).and_return(nil)
    @provider.load_current_resource
    @provider.candidate_version.should eql("4.0")
  end
end

describe Chef::Provider::Package::Openbsd, "package path has no packages" do
  before(:each) do
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "screen",
      :package_name => "screen",
      :source => "ftp://ftp.example.com/packages/",
      :version => nil,
      :options => '-static'
    )

    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)

    @status = mock("Status", :exitstatus => 0)
    @stdin = mock("STDIN", :null_object => true)
    @stdout = mock("STDOUT", :null_object => true)
    @stderr = mock("STDERR", :null_object => true)
    @pid = mock("PID", :null_object => true)

  end

  it "should use a flavor when the flavor option is specified" do
    @provider.should_receive(:popen4).
      with('pkg_info screen',
        :environment => { 'PKG_PATH' => "#{@new_resource.source}"}).
      and_yield(@pid, @stdin, ["No packages available in the PKG_PATH"], @stderr).
      and_return(@status)
    @provider.stub!(:package_name).and_return("screen")
    lambda { @provider.candidate_version}.should raise_error(Chef::Exceptions::Package, "pkg_info screen failed - no packages found in $PKG_PATH, check source")
  end
end

describe Chef::Provider::Package::Openbsd, "ambiguous pkg name, no flavor" do
  before(:each) do
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "screen",
      :package_name => "screen",
      :source => "ftp://ftp.example.com/packages/",
      :version => nil,
      :options => nil
    )

    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)

    @status = mock("Status", :exitstatus => 0)
    @stdin = mock("STDIN", :null_object => true)
    @stdout = mock("STDOUT", :null_object => true)
    @stderr = mock("STDERR", :null_object => true)
    @pid = mock("PID", :null_object => true)

    @pkg_info_output = [
      "Information for #{@new_resource.source}/screen-4.0.3p1.tgz",
      "Information for #{@new_resource.source}/screen-4.0.3p1-shm.tgz",
      "Information for #{@new_resource.source}/screen-4.0.3p1-static.tgz",
    ]
  end

  it "should default to using the basic package" do
    @provider.should_receive(:popen4).
      with('pkg_info screen',
        :environment => { 'PKG_PATH' => "#{@new_resource.source}"}).
      and_yield(@pid, @stdin, @pkg_info_output, @stderr).
      and_return(@status)
    @provider.stub!(:package_name).and_return("screen")
    @provider.stub!(:options)
    @provider.candidate_version.should eql("4.0.3p1")
    @provider.options.should be_nil
  end
end


describe Chef::Provider::Package::Openbsd, "ambiguous pkg name with flavor" do
  before(:each) do
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "screen",
      :package_name => "screen",
      :source => "ftp://ftp.example.com/packages/",
      :version => nil,
      :options => '-static'
    )

    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)

    @status = mock("Status", :exitstatus => 0)
    @stdin = mock("STDIN", :null_object => true)
    @stdout = mock("STDOUT", :null_object => true)
    @stderr = mock("STDERR", :null_object => true)
    @pid = mock("PID", :null_object => true)

    @pkg_info_output = [
      "Information for #{@new_resource.source}/screen-4.0.3p1.tgz",
      "Information for #{@new_resource.source}/screen-4.0.3p1-shm.tgz",
      "Information for #{@new_resource.source}/screen-4.0.3p1-static.tgz",
    ]
  end

  it "should use a flavor when the flavor option is specified" do
    @provider.should_receive(:popen4).
      with('pkg_info screen',
        :environment => { 'PKG_PATH' => "#{@new_resource.source}"}).
      and_yield(@pid, @stdin, @pkg_info_output, @stderr).
      and_return(@status)
    @provider.stub!(:package_name).and_return("screen")
    @provider.candidate_version.should eql("4.0.3p1-static")
  end
end

describe Chef::Provider::Package::Openbsd, "system call wrappers" do
  before(:each) do
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "zsh",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "zsh",
      :version => nil
    )

    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)

    @status = mock("Status", :exitstatus => 0)
    @stdin = mock("STDIN", :null_object => true)
    @stdout = mock("STDOUT", :null_object => true)
    @stderr = mock("STDERR", :null_object => true)
    @pid = mock("PID", :null_object => true)
  end

  it "should return the version number when it is installed" do
    @provider.should_receive(:popen4).
      with('pkg_info zsh').
      and_yield(@pid, @stdin, ["Information for inst:zsh-4.3.6_7"], @stderr).
      and_return(@status)
    @provider.stub!(:package_name).and_return("zsh")
    @provider.current_installed_version.should == "4.3.6_7"
  end

  it "should return nil when the package is not installed" do
    @provider.should_receive(:popen4).
      with('pkg_info zsh').
      and_yield(@pid, @stdin, [], @stderr).
      and_return(@status)
    @provider.stub!(:package_name).and_return("zsh")
    @provider.current_installed_version.should be_nil
  end
end 


describe Chef::Provider::Package::Openbsd, "install_package" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "zsh",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "zsh",
      :version => nil
    )
    @current_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "zsh",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "zsh",
      :version => nil
    )
    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)
    @provider.current_resource = @current_resource
    @provider.stub!(:package_name).and_return("zsh")
  end

  it "should run pkg_add with the package name" do
    @provider.should_receive(:run_command).with({
      :command => "pkg_add zsh-4.3.6_7",
      :environment => { 'PKG_PATH' => "#{@new_resource.source}"}
    })
    @provider.install_package("zsh", "4.3.6_7")
  end
end

describe Chef::Provider::Package::Openbsd, "ruby-iconv (package with a dash in the name)" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "ruby-iconv",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "ruby-iconv",
      :version => nil
    )
    @current_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "ruby-iconv",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "ruby-iconv",
      :version => nil
    )
    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)
    @provider.current_resource = @current_resource
    @provider.stub!(:package_name).and_return("ruby-iconv")
  end

  it "should run pkg_add with the package name" do
    @provider.should_receive(:run_command).with({
      :command => "pkg_add ruby-iconv-1.8.6",
      :environment => { 'PKG_PATH' => "#{@new_resource.source}"}
    })
    @provider.install_package("ruby-iconv", "1.8.6")
  end
end

describe Chef::Provider::Package::Openbsd, "remove_package" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "zsh",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "zsh",
      :version => "4.3.6_7"
    )
    @current_resource = mock("Chef::Resource::Package", 
      :null_object => true,
      :name => "zsh",
      :source => 'ftp://ftp.example.com/packages/',
      :package_name => "zsh",
      :version => "4.3.6_7"
    )
    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)
    @provider.current_resource = @current_resource
    @provider.stub!(:package_name).and_return("zsh")
  end

  it "should run pkg_delete with the package name and version" do
    @provider.should_receive(:run_command).with({
      :command => "pkg_delete zsh-4.3.6_7"
    })
    @provider.remove_package("zsh", "4.3.6_7")
  end
end
