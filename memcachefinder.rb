require 'socket'
require 'ipaddrtargetter'
require File.dirname(__FILE__) + '/debugprint'

include Debug

class MemcacheFinder
  VERSION_STR = "\x01\x03\x00\x00\x00\x01\x00\x00version\r\n"

  attr_writer :read_timeout
  attr_writer :send_wait

#input: array of associate arrays in the form [{:addr=>addr,:ip=>ip}{:addr=>addr,:ip=>ip},,{:addr=>addr,:ip=>ip},...]
  def initialize(targets=nil,read_timeout=5,send_wait=0.1)
    targets=[] if targets.nil?
    @targets=[]

#setup socket for sending/receiving udp packets
    @sock = UDPSocket.new
    @sock.bind("0.0.0.0",0)

#read timeout for group of transmissionss
    @read_timeout = read_timeout
    @send_wait = send_wait

    self.add_targets(targets)
    self
  end

  def add_targets(targets)
    raise Exception.new("MemcacheFinder requires an array of targets in iniatlize()") if !targets.is_a?(Array)
    @targets << targets
  end

  def find_addr_group(targets,port=11211,&block)
    target_storage=[]
    targets.each{|target|
      @sock.send(VERSION_STR, 0, target[:ip], 11211)
      dprint "Sending UDP version check to #{target[:ip]}"
      sleep(@send_wait)
    }

    outstanding_targets = targets.size
    
    t1 = Time.new.to_f
    while outstanding_targets > 0 and Time.new.to_f-t1 < @read_timeout do
      IO.select([@sock],nil,nil,@read_timeout)
      begin
        while true do
#if there are datagrams waiting to be processed, loop through them. as soon as none are available, the exception is thrown
#and the "while true" is aborted
          dgram = @sock.recvfrom_nonblock(100)
          msg = dgram[0].strip
          ip = dgram[1][3]
          if msg.size <= 8 or msg[0] != 0x01 or msg[1] != 0x03 or msg[5] != 0x01 then
#appears to be an unknown service, not responding with the expected data. print a warning and ignore
            puts "[warning] Packet received that does not seem to be a memcached version answer"
          else
#got a reply. figure out who the sender was, save it and remove from the list we're waiting for
            version = msg[8..msg.size]
            target_storage << {:ip => ip, :version => version}
            outstanding_targets -= 1
#optional callback as each target is discovered
            yield target_storage.last if block_given?
          end
        end
      rescue Errno::EAGAIN
      end
    end
    target_storage
  end

end

@@minl = INFO
t = IPAddrTargetter.new(ARGV.join(" "))
mf = MemcacheFinder.new
mf.send_wait=0.0
#mf.add_targets([{:ip=>"127.0.0.1",:addr=>"localhost"}])
while !(g=t.get_group(2048)).empty? do
  mf.find_addr_group(g) {|struct|
    puts "#{struct[:ip]} speaks #{struct[:version]}"
  }
end

