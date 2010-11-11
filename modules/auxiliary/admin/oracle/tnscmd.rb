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

class Metasploit3 < Msf::Auxiliary

	include Msf::Exploit::Remote::TNS

	def initialize(info = {})
		super(update_info(info,
			'Name'           => 'TNSLsnr Command Issuer',
			'Description'    => %q{
				This module allows for the sending of arbitrary TNS commands in order
				to gather information.
				Inspired from tnscmd.pl from www.jammed.com/~jwa/hacks/security/tnscmd/tnscmd
			},
			'Author'         => ['MC'],
			'License'        => MSF_LICENSE,
			'Version'        => '$Revision$',
			'DisclosureDate' => 'Feb 1 2009'
		))

		register_options(
			[
				Opt::RPORT(1521),
				OptString.new('CMD', [ false, 'Something like ping, version, status, etc..', '(CONNECT_DATA=(COMMAND=VERSION))']),
			], self.class)
	end

	def run
		connect

		command = datastore['CMD']

		pkt = tns_packet(command)

		print_status("Sending '#{command}' to #{rhost}:#{rport}")
		sock.put(pkt)
		print_status("writing #{pkt.length} bytes.")

		select(nil,nil,nil,0.5)

		print_status("reading")
		res = sock.get_once(-1,5)
		res = res.tr("[\200-\377]","[\000-\177]")
		res = res.tr("[\000-\027\]",".")
		res = res.tr("\177",".")
		puts res

		disconnect
	end
end
