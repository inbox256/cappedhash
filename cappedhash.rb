#
# A little hash override to cache the "N most-used" objects.
# Requires use of fetch method to add and retrieve elements.  The hash's value is
# modified to include a request count.
#
require 'monitor'

class CappedHash < Hash
  DEFAULT_CAPPED_SIZE = 1000 # Never cache more than this many.
  DEFAULT_KEEP_SIZE = 100 # Amount to always keep in hash cache. Must be less than CAPSIZE

  def initialize(capped_size = DEFAULT_CAPPED_SIZE, keep_size = DEFAULT_KEEP_SIZE)
    self.extend MonitorMixin # support multithreaded use in jruby (mri does not need a lock)
    @capped_size = capped_size
    @keep_size = keep_size
    super(nil)
  end

  def fetch(key)

    self.synchronize {
      #puts "cappedhash.fetch(#{key})"
      # Call base class fetch
      super(key) do |el|
        # need to add new element, but first check if over capsize & need to reset
        if self.size >= @capped_size
          # puts "...time to cleanup"
          ary = self.sort_by {|k, v| v[0]}.take(self.size-@keep_size) # get least used
          ary.each { |hel| self.delete(hel[0]) }  # del least used
          self.each_value {|value| value[0] = 0}          # zero the request counts
        end
        #puts "add to cache"
        # Add new element. Hashes value passed in via block
        self[el] = [0, yield] # add new hash element
      end
      #puts "use cache"
      #puts "self[#{key}] => #{self[key].inspect}"

      self[key][0]+=1 # increment request count
      self[key][1]    # return real value, not internal count

    }

  end

  #
  # Get actual request count.
  #
  def request_count(key)
    self[key][0] rescue 0
  end

  def to_s
    self.synchronize {
      s = []
      s << "capped hash size #{self.size}. "
      self.sort_by {|k, v| v[0]}.reverse.each do |k,v|
        s << "#{k}:#{v[0] rescue nil}"
      end
      s.join(' ')
    }
  end

end

if $0 == __FILE__

  # Example code.  Change CAPPED_SIZE to 4 and KEEP_SIZE to 2 to test
  ch = CappedHash.new(4,2)
  # populate for testing
  ch.merge!({:one => [1, 'one'], :two => [2, 'two'], :three => [3,'thr'], :four => [4,'for'], :five => [5, 'five'] })
  puts ch
  puts ":one is #{ch.fetch(:one) {"one"}}"
  puts "request_count for :one should be 2: #{ch.request_count(:one)}"

  puts ":new is #{ch.fetch(:new) {'something_new'} }"
  puts "request_count for new: #{ch.request_count(:new)}"
  puts "#{ch} # Look resized!"

  puts ":new is #{ch.fetch(:new) {'something_new'} }"
  puts "request_count for new: #{ch.request_count(:new)}"
  puts ch

end

