#!/usr/bin/ruby
# encoding: utf-8 

class Integer
	def rol(shift, width = (size * 8))
		(self << shift | self >> (width - shift)) & (2 ** width - 1)
	end
end

class Keccak
	RoundConsts = [
		0x0000000000000001, 0x0000000000008082,
		0x800000000000808A, 0x8000000080008000,
		0x000000000000808B, 0x0000000080000001,
		0x8000000080008081, 0x8000000000008009,
		0x000000000000008A, 0x0000000000000088,
		0x0000000080008009, 0x000000008000000A,
		0x000000008000808B, 0x800000000000008B,
		0x8000000000008089, 0x8000000000008003,
		0x8000000000008002, 0x8000000000000080,
		0x000000000000800A, 0x800000008000000A,
		0x8000000080008081, 0x8000000000008080,
		0x0000000080000001, 0x8000000080008008
	]

	RotationOffsets = [
		[0, 36, 3, 41, 18],
		[1, 44, 10, 45, 2],
		[62, 6, 43, 15, 61],
		[28, 55, 25, 21, 56],
		[27, 20, 39, 8, 14]
	]

	def initialize(output_size = 512, bitrate = 1024, capacity = 576)
		@output_size = output_size / 8
		@bitrate = bitrate / 8
		@capacity = capacity / 8
		@block_size = @bitrate + @capacity
		@lane_size = @block_size * 8 / 25
		@mask = 2 ** @lane_size - 1
		@pack_code = case @lane_size
			when 8 then 'C'
			when 16 then 'S'
			when 32 then 'L'
			when 64 then 'Q'
		end
		@l = Math.log2(@lane_size).to_i
		@num_rounds = 12 + 2 * @l
		@state = [
			[0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0]
		]
	end

	def digest(input)
		# pad input
		input.force_encoding('binary')
		input << "\1"
		input << ("\0" * (@bitrate - (input.length % @bitrate) - 1) + "\x80").force_encoding('binary')

		# absorb input
		while input.length > 0
			block = (input.slice!(0...@bitrate) + "\0" * @capacity).unpack(@pack_code + '<*')
			(0..4).each {|x|
				(0..4).each {|y| @state[x][y] ^= block[x + 5 * y] }
			}
			keccak_f
		end

		# squeeze output
		output = ''.force_encoding('binary')
		while output.length < @output_size
			output += @state.transpose.map {|row| row.pack(@pack_code + '<*') }.join[0...@bitrate]
			keccak_f if output.length < @output_size
		end
		output[0...@output_size]
	end

	def Keccak.digest(input, *args)
		Keccak.new(*args).digest(input)
	end

	def keccak_f
		(0...@num_rounds).each {|i|
			# θ
			c = @state.map {|row| row.reduce(:^) }
			(0..4).each {|x|
				d = c[(x - 1) % 5] ^ c[(x + 1) % 5].rol(1, @lane_size)
				@state[x].map! {|lane| lane ^ d }
			}

			# ρπ
			b = [[], [], [], [], []]
			(0..4).each {|x|
				(0..4).each {|y| b[y][(2 * x + 3 * y) % 5] = @state[x][y].rol(RotationOffsets[x][y], @lane_size) }
			}

			# χ
			(0..4).each {|x|
				(0..4).each {|y| @state[x][y] = b[x][y] ^ ((~b[(x + 1) % 5][y] & @mask) & b[(x + 2) % 5][y]) }
			}

			# ι
			@state[0][0] ^= RoundConsts[i] & @mask
		}
	end
end

if $0 == __FILE__
	input = ARGV.shift.dup
	size = ARGV.shift
	size = size ? size.to_i : 512
	puts Keccak.digest(input, size).bytes.map {|b| '%02x' % b }.join
end
