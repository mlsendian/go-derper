require 'socket'

class IPAddrTargetter
  attr_writer :addresses
  attr_writer :include_reverses

  def initialize(addresses,include_reverses=false)
    @addresses=[]
    self.add_addr_block(addresses) if !addresses.nil?
    @completed_addresses=[]
    @include_reverses = include_reverses
  end

#this method will return all mappings between A and CNAME records and IP addresses for a given DNS name
  def parse_dns(address)
    fwd_entries={}
    aliases=nil
    begin
      Socket.getaddrinfo(address,nil).each do |addr_struct|
        addr=addr_struct[2]
        ip=addr_struct[3]
        if fwd_entries[addr].nil?
          fwd_entries[addr]=[ip]
        elsif !fwd_entries[addr].include?(ip)
          fwd_entries[addr] << ip
        end
      end
      rescue SocketError =>e
    end
    ret_arr=[]
    if fwd_entries.empty? then
      puts "[warning] Could not determine an IP address for \"#{address}\""
    else
      fwd_entries.each do |fwd,ips|
        ips.each do |ip|
          ret_arr << {:ip=>ip, :addr=>fwd}
        end
      end
    end
    return ret_arr
  end

  def parse_ip(ip_address)
    ips=[""]#include a dummy entry, makes .each work on the 1st round
    if ip_address.include?("*") or ip_address.include?("-")
#this block handles ip address ranges in either * or - form
      ip_address.split(/\./).each do |octet|
        if octet =~ /(^[0-9]+$)/ or octet =~ /^(\*)$/ or octet=~ /^(-)([0-9]+)$/ or octet=~/^([0-9]+)(-)$/ or octet =~ /^([0-9]+)-([0-9]+$)/ then
#default case is *, so we don't need to check for it
          octet_start=0;octet_end=255
          if !$2.nil? then
#if the shorthand "40-" or "-100" is used
            octet_start = $1.to_i if $1 != "-"
            octet_end = $2.to_i if $2 != "-"
          elsif octet =~ /^([0-9]+)$/
            octet_start = $1.to_i
            octet_end = $1.to_i
          end
          raise Exception.new("Start of range can't be past the end: \"#{octet_start}\"-\"#{octet_end}\"") if octet_start > octet_end
          raise Exception.new("Start of range can't be greater than 255: \"#{octet_start}\"-\"#{octet_end}\"") if octet_start > 255
          raise Exception.new("End of range can't be greater than 255: \"#{octet_start}\"-\"#{octet_end}\"") if octet_end > 255
          new_ips=[]
          ips.each do |ip|
            octet_start.upto(octet_end) do |i| 
              new_ips << ("#{ip}#{(ip=="")?"":"."}#{i.to_s}")  
            end
          end
          ips=new_ips
        else
          raise Exception.new("Octet is not in the required format: \"#{octet}\"") 
        end
      end
    else
#here we handle individual ip addresses
      ip_address.split(/\./).each do |octet|
            raise Exception.new("Octet can't be greater than 255: \"#{octet}\"") if octet.to_i > 255
            raise Exception.new("Octet can't be less than 0: \"#{octet}\"") if octet.to_i < 0
      end
      ips << ip_address
    end
    
    ips.delete("")#remove the dummy entry
    if @include_reverses
      ips=ips.collect {|ip| {:ip=>ip, :addr=>Socket.getaddrinfo(ip,nil)[0][2]}}
    else
      ips=ips.collect {|ip| {:ip=>ip, :addr=>nil}}
    end
    ips
  end

  def parse_addresses(address_line)
    label_reg = "([0-9*-])"
    component_ips = []
    
#break up lines of "<address_black> <address_block> <address_block>"
    if address_line =~ / / then
      address_line.split.each {|address_block|
       component_ips+=(self.parse_addresses(address_block))
      }
      return component_ips
    else
      if address_line =~ /^([0-9*-]+)\.([0-9*-]+)\.([0-9*-]+)\.([0-9*-]+$)/
#parsing x.x.x.x, x.x.x.*, x.x.x.4-10
        component_ips+=(self.parse_ip(address_line))
      else
#parsing DNS names
        component_ips+=(self.parse_dns(address_line))
      end
    end

    component_ips
  end

  def add_addr_block(block)
    if block.is_a?(String)
      @addresses+=(parse_addresses(block))
    elsif block.is_a?(Array)
      block.each {|addrs|
        @addresses+=(parse_addresses(addrs))
      }
    else
      raise Exception.new("add_addr_block(): Could not parse address type #{block.class}")
    end
    #@addresses.each {|addr| puts "#{addr[:addr]}=>#{addr[:ip]}" }
  end

  def each (&block)
    @addresses.each {|addr|
      yield addr
    }
  end

  def get_next (&block)
    return nil if @addresses.empty?

    addr=@addresses.shift
    @completed_addresses << addr
    addr
  end

  def rewind
    @addresses = @completed_addresses + @addresses
  end

  def get_group(group_size=10)
    ret_arr=[]
    0.upto(group_size-1) { ret_arr << self.get_next }

    ret_arr.compact
  end
end


#targets = IPAddrTargetter.new

#targets.include_reverses = true
#targets.add_addr_block("www.youtube.com 192.168.100.1 172.16.1.* 10.1.1.50-194")
#targets.each {|struct| puts "#{struct[:addr]}=>#{struct[:ip]}" }

#while struct=targets.next do
#  puts "#{struct[:addr]}=>#{struct[:ip]}" 
#end
#targets.rewind
#while struct=targets.next do
#  puts "#{struct[:addr]}=>#{struct[:ip]}" 
#end
