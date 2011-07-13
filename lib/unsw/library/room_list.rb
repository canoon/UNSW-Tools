class Library::RoomList
  attr_accessor :rooms
  
	DOC_NUMBER = '001342140'
	DOC_LIBRARY = 'NSW01'
	
	def initialize(aleph)
		@aleph = aleph
	end
	
	def load
		doc = Nokogiri::HTML(@aleph.fcall({:func => 'item-global', 
		  :doc_number => DOC_NUMBER, :doc_library => DOC_LIBRARY}))
		@ids = []
		doc.xpath('//a[.="Booking"]').each do |x|
			@ids << Library::unparameterize(x['href'])['adm_item_sequence']
	  end
		$log.debug @ids
		$log.debug @ids.length
	end
	
	def loadAll
	  ids = @ids.collect do |x|
			[x, Library::Room.new(@aleph.fcall({:func => 'booking-req-form-itm', 
			      :adm_library => 'NSW50', :adm_doc_number => DOC_NUMBER,
			      :adm_item_sequence => x}))]
		end
		@rooms = Hash[ids]
	end
	
end