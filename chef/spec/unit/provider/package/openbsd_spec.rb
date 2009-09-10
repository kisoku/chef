#
# Authors:: Mathieu Sauve-Frankel <msf@openbsd.org>
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

    @provider.should_receive(:candidate_version).and_return("4.0")
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

describe Chef::Provider::Package::Openbsd, "system call wrappers" do
  before(:each) do
    @new_resource = mock("Chef::Resource::Package", 
      :null_object => true,
      :name => "zsh",
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
    @provider.should_receive(:popen4).with('pkg_info -E "zsh*"').and_yield(@pid, @stdin, ["zsh-4.3.6_7"], @stderr).and_return(@status)
    @provider.stub!(:package_name).and_return("zsh")
    @provider.current_installed_version.should == "4.3.6_7"
  end

  it "should return nil when the package is not installed" do
    @provider.should_receive(:popen4).with('pkg_info -E "zsh*"').and_yield(@pid, @stdin, [], @stderr).and_return(@status)
    @provider.stub!(:package_name).and_return("zsh")
    @provider.current_installed_version.should be_nil
  end
  
  it "should return the port path for a valid port name" do
    @provider.should_receive(:popen4).with("whereis -s zsh").and_yield(@pid, @stdin, ["zsh: /usr/ports/shells/zsh"], @stderr).and_return(@status)
    @provider.stub!(:port_name).and_return("zsh")
    @provider.port_path.should == "/usr/ports/shells/zsh"
  end

  # Not happy with the form of these tests as they are far too closely tied to the implementation and so very fragile.
  it "should return the ports candidate version when given a valid port path" do
    @provider.should_receive(:port_path).and_return("/usr/ports/shells/zsh")
    @provider.should_receive(:popen4).with("cd /usr/ports/shells/zsh; make -V PORTVERSION").and_yield(@pid, @stdin, @stdout, @stderr).and_return(@status)
    @stdout.should_receive(:readline).and_return("4.3.6\n")
    @provider.ports_candidate_version.should == "4.3.6"
  end
  
  it "should figure out the package name" do
    @provider.should_receive(:ports_makefile_variable_value).with("PKGNAME").and_return("zsh-4.3.6_7")
    @provider.package_name.should == "zsh"
  end
end

describe Chef::Provider::Package::Openbsd, "install_package" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "zsh",
      :package_name => "zsh",
      :version => nil
    )
    @current_resource = mock("Chef::Resource::Package", 
      :null_object => true,
      :name => "zsh",
      :package_name => "zsh",
      :version => nil
    )
    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)
    @provider.current_resource = @current_resource
    @provider.stub!(:package_name).and_return("zsh")
    @provider.stub!(:latest_link_name).and_return("zsh")
  end

  it "should run pkg_add -r with the package name" do
    @provider.should_receive(:run_command).with({
      :command => "pkg_add -r zsh",
    })
    @provider.install_package("zsh", "4.3.6_7")
  end

  it "should run make install when installing from ports" do
    @new_resource.stub!(:source).and_return("ports")
    @provider.should_receive(:port_path).and_return("/usr/ports/shells/zsh")
    @provider.should_receive(:run_command).with(:command => "make -DBATCH install", :cwd => "/usr/ports/shells/zsh")
    @provider.install_package("zsh", "4.3.6_7")
  end
end

describe Chef::Provider::Package::Openbsd, "port path" do
  it "should figure out the port path from the package_name using whereis" do
    @new_resource = mock("Chef::Resource::Package", :package_name => "zsh")
    @provider = Chef::Provider::Package::Openbsd.new(mock("Chef::Node"), @new_resource)
    @provider.should_receive(:popen4).with("whereis -s zsh").and_yield(nil, nil, ["zsh: /usr/ports/shells/zsh"], nil)
    @provider.port_path.should == "/usr/ports/shells/zsh"
  end
  
  it "should use the package_name as the port path when it starts with /" do
    @new_resource = mock("Chef::Resource::Package", :package_name => "/usr/ports/www/wordpress")
    @provider = Chef::Provider::Package::Openbsd.new(mock("Chef::Node"), @new_resource)
    @provider.should_not_receive(:popen4)
    @provider.port_path.should == "/usr/ports/www/wordpress"
  end
  
  it "should use the package_name as a relative path from /usr/ports when it contains / but doesn't start with it" do
    @new_resource = mock("Chef::Resource::Package", :package_name => "www/wordpress")
    @provider = Chef::Provider::Package::Openbsd.new(mock("Chef::Node"), @new_resource)
    @provider.should_not_receive(:popen4)
    @provider.port_path.should == "/usr/ports/www/wordpress"
  end 
end

describe Chef::Provider::Package::Openbsd, "ruby-iconv (package with a dash in the name)" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "ruby-iconv",
      :package_name => "ruby-iconv",
      :version => nil
    )
    @current_resource = mock("Chef::Resource::Package", 
      :null_object => true,
      :name => "ruby-iconv",
      :package_name => "ruby-iconv",
      :version => nil
    )
    @provider = Chef::Provider::Package::Openbsd.new(@node, @new_resource)
    @provider.current_resource = @current_resource
    @provider.stub!(:port_path).and_return("/usr/ports/converters/ruby-iconv")
    @provider.stub!(:package_name).and_return("ruby18-iconv")
    @provider.stub!(:latest_link_name).and_return("ruby18-iconv")
  end

  it "should run pkg_add -r with the package name" do
    @provider.should_receive(:run_command).with(:command => "pkg_add -r ruby18-iconv")
    @provider.install_package("ruby-iconv", "1.0")
  end

  it "should run make install when installing from ports" do
    @new_resource.stub!(:source).and_return("ports")
    @provider.should_receive(:run_command).with(:command => "make -DBATCH install", :cwd => "/usr/ports/converters/ruby-iconv")
    @provider.install_package("ruby-iconv", "1.0")
  end
end

describe Chef::Provider::Package::Openbsd, "remove_package" do
  before(:each) do
    @node = mock("Chef::Node", :null_object => true)
    @new_resource = mock("Chef::Resource::Package",
      :null_object => true,
      :name => "zsh",
      :package_name => "zsh",
      :version => "4.3.6_7"
    )
    @current_resource = mock("Chef::Resource::Package", 
      :null_object => true,
      :name => "zsh",
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
