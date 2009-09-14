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
          status = popen4(command) do |pid, stdin, stdout, stderr|
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
          # We use pkg_info to determine the available package version.
          # pkg_info may return more than one result and so we need to
          # examine the results in order to determine the best match.
          # When no option is set on the package resource and multiple
          # FLAVORs of a package have been found we default to using
          # the unflavored package, otherwise try using the string stored
          # in option to match 
          case @new_resource.source
          when /(((?:(?:https?|ftp|scp):\/\/|[\/.]+)[\w.\/]+(?::)?)?)/
            candidates = []
            command = "pkg_info #{@new_resource.package_name}"
            env = { 'PKG_PATH' => "#{@new_resource.source}" }
            status = popen4(command, :environment => env) do |pid, stdin, stdout, stderr|
              stdout.each do |line|
                case line 
                when /^Information for #{@new_resource.source}\/#{@new_resource.package_name}-([\w\d.-]+).tgz/
                  candidates << $1
                when /^No packages available in the PKG_PATH/
                  raise Chef::Exceptions::Package, "#{command} failed - no packages found in $PKG_PATH, check source"
                end
              end
            end
          else
            raise Chef::Exceptions::Package, "invalid source specified for package: #{@new_resource.package_name}"
          end
          if candidates.length > 1 
            if expand_options(@new_resource.options).empty?
              return candidates.sort.shift
            else
              return candidates.grep(/#{@new_resource.options}/).to_s
            end
          else
            return candidates.shift.to_s
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
              if version
                run_command(
                  :command => "pkg_add #{@new_resource.package_name}-#{version}",
                  :environment => { "PKG_PATH" => @new_resource.source }
                )
                Chef::Log.info("Installed package #{@new_resource.package_name} from: #{@new_resource.source}")
              else
                run_command(
                  :command => "pkg_add #{@new_resource.package_name}",
                  :environment => { "PKG_PATH" => @new_resource.source }
                )
                Chef::Log.info("Installed package #{@new_resource.package_name} from: #{@new_resource.source}")
              end
            when /^No packages available in the PKG_PATH/
              raise Chef::Exceptions::Package, "#{command} failed - no packages found in $PKG_PATH, check source"
            else
              raise Chef::Exceptions::Package, "invalid source specified for package: #{@new_resource.package_name}"
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
          if @current_resource.version
            case @new_resource.source
            when /(((?:(?:https?|ftp|scp):\/\/|[\/.]+)[\w.\/]+(?::)?)?)/
              run_command(
                :command => "pkg_add -u -F update -F updatedepends #{@new_resource.package_name}",
                :environment => { 
                  "PKG_PATH"     => "#{@new_resource.package_name}"
                }
              )
            when /^No packages available in the PKG_PATH/
              raise Chef::Exceptions::Package, "#{command} failed - no packages found in $PKG_PATH, check source"

            else
              raise Chef::Exceptions::Package, "invalid source specified for package: #{@new_resource.package_name}"
            end
          else
            install_package(name,version)
          end
        end  
      end
    end
  end
end
