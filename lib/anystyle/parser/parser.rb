module Anystyle
	module Parser

		class Parser

			@defaults = {
				:model => File.expand_path('../support/anystyle.mod', __FILE__),
				:pattern => File.expand_path('../support/anystyle.pat', __FILE__),
				:separator => /\s+/,
				:tagged_separator => /\s+|(<\/?[^>]+>)/,
				:strip => /\W/
			}.freeze
			
			@features = []
			@feature = Hash.new { |h,k| h[k.to_sym] = features.detect { |f| f.name == k.to_sym } }
			
			class << self

				attr_reader :defaults, :features, :feature
								
				def load(path)
					p = new                                    
					p.model = Wapiti.load(path)
					p
				end

				# Returns a default parser instance
				def instance
					@instance ||= new
				end
				
			end
			
			attr_reader :options
			
			attr_accessor :model
			
			def initialize(options = {})
				@options = Parser.defaults.merge(options)
				@model = Wapiti.load(@options[:model])
			end
			
			def parse(string)
				label(string)
			end
			
			def label(string)
				model.label(prepare(string)) do |token, label|
					[token[/\S+/], label]
				end
			end
			
			# Returns an array of tokens for each line of input.
			#
			# If the passed-in string is marked as being tagged, extracts labels
			# from the string and returns an array of token/label pairs for each
			# line of input.
			def tokenize(string, tagged = false)
				if tagged
					string.split(/[\n\r]+/).each_with_index.map do |s,i|
						tt, tokens, tags = s.split(options[:tagged_separator]), [], []

						tt.each do |token|
							case token
							when /^$/
								# skip
							when /^<([^\/>][^>]*)>$/
								tags << $1
							when /^<\/([^>]+)>$/
								unless (tag = tags.pop) == $1
									raise ArgumentError, "mismatched tags on line #{i}: #{$1.inspect} (current tag was #{tag.inspect})"
								end
							else
								tokens << [token, (tags[-1] || :unknown).to_sym]
							end
						end

						tokens
					end
				else
					string.split(/[\n\r]+/).map { |s| s.split(options[:separator]) }
				end
			end

			# Prepares the passed-in string for processing by a CRF tagger. The
			# string is split into separate lines; each line is tokenized and
			# expanded. Returns an array of sequence arrays that can be labelled
			# by the CRF model.
			#
			# If the string is marked as being tagged by passing +true+ as the
			# second argument, training labels will be extracted from the string
			# and appended after feature expansion. The returned sequence arrays
			# can be used for training or testing the CRF model.
			def prepare(string, tagged = false)
				tokenize(string, tagged).map { |tk| tk.each_with_index.map { |(t,l),i| expand(t,tk,i,l) } }
			end


			# Expands the passed-in token string by appending a space separated list
			# of all features for the token.
			def expand(token, sequence = [], offset = 0, label = nil)
				f = features_for(token, strip(token), sequence, offset)
				f.unshift(token)
				f.push(label) unless label.nil?
				f.join(' ')
			end
			
			private
			
			def features_for(*arguments)
				Parser.features.map { |f| f.match(*arguments) }
			end
			
			def strip(token)
				token.gsub(options[:strip], '')
			end
			
		end

	end
end