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

require 'chef/provider/package'
require 'chef/mixin/command'
require 'chef/resource/package'

class Chef
  class Provider
    class Package
      class Openbsd < Chef::Provider::Package
        def current_installed_version
          command = "pkg_info #{@new_resource.package_name}"
          env = { 'PKG_PATH' => "#{@new_resource.source}" }
          status = popen4(command, :environment => env) do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              case line
              when /^Information for inst:#{package_name}-(.+)/
                return $1
              end
            end
          end
          unless status.exitstatus == 0 || status.exitstatus == 1
            raise Chef::Exceptions::Package, "#{command} failed - #{status.inspect}!"
          end
          nil
        end

        def candidate_version
          # here we use pkg_info to determine the available package version
          # pkg_info may return more than one result and so we need to
          # examine the results in order to determine the best match
          # TODO: add support for packages that have FLAVOR, see OpenBSD's
          # bsd.port.mk(5) for more details about FLAVOR
          case @new_resource.source
          when /(((?:(?:https?|ftp|scp):\/\/|[\/.]+)[\w.\/]+(?::)?)?)/
            candidates = []
            command = "pkg_info #{@current_resource.package_name}"
            env = { 'PKG_PATH' => "#{@current_resource.source}" }
            status = popen4(command, :environment => env) do |pid, stdin, stdout, stderr|
              stdout.each do |line|
                case line 
                when /^Information for #{@current_resource.package_name}-([\w\d.-]+).tgz/
                  candidates << $1
                end
              end
            end
          end
        end

        def load_current_resource
          @current_resource = Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)
        
          @current_resource.version(current_installed_version)
          Chef::Log.debug("Current version is #{@current_resource.version}") if @current_resource.version
          
          @candidate_version = candidate_version
          Chef::Log.debug("Candidate version is #{@candidate_version}") if @candidate_version
          @current_resource
        end

        def install_package(name, version)
          unless @current_resource.version
            case @new_resource.source
            when /(((?:(?:https?|ftp|scp):\/\/|[\/.]+)[\w.\/]+(?::)?)?)/
              run_command(
                :command => "pkg_add #{@new_resource.package_name}",
                :environment => { "PKG_PATH" => @new_resource.source }
              )
              Chef::Log.info("Installed package #{@new_resource.package_name} from: #{@new_resource.source}")
            end
          end
        end

        def remove_package(name, version)
          if version
            run_command(
              :command => "pkg_delete #{@new_resource.package_name}-#{version}"
            )
          else
            run_command(
              :command => "pkg_delete #{@new_resource.package_name}"
            )
          end
        end

        def upgrade_package(name, version)
          run_command(
            :command => "pkg_add -u -F depends -F updatedepends #{@current_resource.package_name}",
            :environment => { "FORCE_UPDATE" => "YES" }
          )
        end  
      end
    end
  end
end
