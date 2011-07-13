class Library::Room
	def initialize(string)
		@table = Library::Room.parse(string)
	end	
	
	def self.parse(string)
		table = {}
		cur_date = ""
		string.each_line do |line|
			if (line =~ /^var mystring = "([0-9\/]*)";/)
				cur_date = $~[1]
				table[cur_date] = {}
			elsif (line =~ /^print_date\("(notavail|avail)",([0-9]+)\);/)
				table[cur_date][$~[2].to_i] = $~[1]
			end
		end
		return table
	end
	
	def get_dates
		return @table.keys
	end
	
	def get_hours
		return @table.values.collect{|x| x.keys}.flatten.uniq.sort
	end
	
	def check(date, hour)
		return @table[date][hour]
	end
	
	def inspect
		return "Time:\t" + get_hours.join("\t") + "\n" + @table.collect{ |k, v|  "#{k}\t" + get_hours.collect{|x| v[x]}.join("\t") }.join("\n")
	end
	
	def to_s
		return @table.collect{ |k, v|  get_hours.collect{|x| v[x][0].chr}.join("") }.join("")
	end
	
end
