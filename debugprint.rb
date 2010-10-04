module Debug
  DEBUG=1
  VERBOSE=2
  INFO=3
  WARNING=4
  ERROR=5
  NONE=6
  @@minl = INFO

  def dbgprint(level, msg)
    if level >= @@minl then
      case level
        when DEBUG
          print "[d] "
        when VERBOSE
          print "[v] "
        when INFO
          print "[i] "
        when WARNING
          print "[w] "
        when ERROR
          print "[E] "
      end
      puts msg
    end
  end

  def dprint(msg)
    dbgprint(Debug::DEBUG, msg)
  end

  def vprint(msg)
    dbgprint(Debug::VERBOSE, msg)
  end

  def iprint(msg)
    dbgprint(Debug::INFO, msg)
  end

  def wprint(msg)
    dbgprint(Debug::WARNING, msg)
  end

  def eprint(msg, die=false)
    dbgprint(Debug::ERROR, msg)
    exit(1) if die
  end
end
