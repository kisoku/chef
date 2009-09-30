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

require 'chef/provider/service'
require 'chef/mixin/command'

class Chef
  class Provider
    class Service
      class Openbsd < Chef::Provider::Service::Simple
        include Chef::Mixin::ParamsValidate

        def load_current_resource

          super

          #validate(
          #  { :enable_variable => @current_resource.options[:enable_variable]}, 
          #  { :enable_variable => { :kind_of => String }}
          #)
          #validate(
          #  { :enable_flags => @current_resource.options[:enable_flags]}, 
          #  { :enable_flags => { :kind_of => String }}
          #)
          #
          #
          unless ::File.exists? "/etc/rc.conf.local"
            raise Chef::Exceptions::Service, "/etc/rc.conf.local does not exist"
          end
 
          lines = read_rc_conf_local

          lines.each_line do |line|
            if line =~ /^#{enable_variable}=#{enable_flags}/
                @current_resource.enabled true
            else
                @current_resource.enabled false
            end
          end

          @current_resource
        end
        

        def set_enable_variable(value)
          lines = read_rc_conf_local
          # Remove line that set the old value
          lines.delete_if { |line| line =~ /#{enable_variable}/ }
          # And append the line that sets the new value at the end
          lines << "#{enable_variable}=\"#{value}\""
          write_rc_conf_local(lines)
        end

        def enable_variable
          @current_resource.options[:enable_variable]
        end

        def enable_flags 
          @current_resource.options[:enable_flags]
        end

        def enable_service
          set_enable_variable(enable_flags) unless @current_resource.enabled
        end

        def disable_service
          set_enable_variable("NO") if @current_resource.enabled
        end

        def read_rc_conf_local
          ::File.open("/etc/rc.conf.local", 'r') { |file| file.readlines }
        end

        def write_rc_conf_local(lines)
          ::File.open("/etc/rc.conf.local", 'w') do |file|
            lines.each { |line| file.puts(line) }
          end
        end
      end
    end
  end
end
