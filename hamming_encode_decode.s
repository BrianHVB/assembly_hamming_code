

	AREA hamming_main, CODE, READONLY
	EXPORT main
	ENTRY
	
main
	BL decode
	
exit
	MOV R10, #0
	STRB R10, [R3, R4]
	MOV r0, #0x18      
	LDR r1, =0x20026   
	SVC #0x11			
	

	AREA hamming_decode, CODE, READONLY
	EXPORT decode
decode

	LDR R1, =hCode - 1		;encoded_array
	MOV R2, #0				;encode offset
	
	LDR R3, =srcWord - 1	;decoded_array
	MOV R4, #1				;decode offset
	
	MOV R5, #1				;Power of two
	MOV R6, #0				;accumulator
	MOV R10, #0				;symbol
	
decode_loop_a
	ADD R2, #1				;increment counter
	LDRB R10, [R1, R2]		;load a symbol
	
	CMP R10, #0
	BEQ end_decode_loop_a
	
	;check for invalid symbols
	CMP R10, #'0'	
	BLLT invalid_symbol_error	
	CMP R10, #'1'
	BLGT invalid_symbol_error
	
	;if symbol is a 1, add it to accumulator
	IT EQ
		EOREQ R6, R2
	
	;skip parity bits when decoding
	CMP R2, R5				;compare position with current twos power
	ITT EQ
		LSLEQ R5, #1		;increment power, skip symbol
		BEQ decode_loop_a	;loop
		
	;else
	STRB R10, [R3, R4]		;append the symbol
	ADD R4, #1				;increment the offset
	B decode_loop_a			;loop

end_decode_loop_a
	;error detection
	CMP R6, #0				;if accumulator is 0, the no error in code
	BEQ exit
	
	;error correction
	;else, accumulator holds the position of the error
	;use helper function to map position
	PUSH {R6}				;pass a value
	BL convert_bit_position
	POP {R6}				;get return value
	
	;R6 holds the value of the flipped bit in srcWrd.
	;if 0, then the flipped bit was a check bit and can be ignored
	CMP R6, #0
	BEQ exit
	
	;else, correct the error, using a helper function to flip it
	LDRB R0, [R3, R6]		;get the bit
	PUSH {R0}				;pass it
	BL flip_bit				;to a routine
	POP {R0}				;get the rtn value
	STRB R0, [R3, R6]		;write
	
	BL exit



	ALIGN
	AREA hamming_helper_functions, CODE, READONLY
	EXPORT convert_bit_position
	EXPORT flip_bit
	EXPORT invalid_symbol_error



	;Uses a loop to find the greatest power of two that is lower than the position
	;of the errored bit in the encoded string. This power serves as the offset that
	;will determine the location of the same bit in the decoded string.
	;
	;If the location of the error is one of the check/parity bits, then this will equal a twos power
	;and the error can safely be ignored. In this case, the function returns.
	;
	;This is a small efficieny improvement over using seperate loops to both detect/correct the error, and to then
	;reduce the message and extract the data bits. Instead, only one loop is needed to do both, and this helper
	;functions runs in O{log n) complexity.
convert_bit_position
	POP {R0}			;R0 = position in encoded string
	MOV R9, #0			;R9 = offset
	MOV R8, #1			;powers of two
cbp_loop_a
	CMP R8, R0			;see if the position is less than 2^n
	IT EQ
		MOVEQ R9, R0	;if equal, then error in in a check bit and can be ignored
	BGE cbp_loop_a_exit
	;less than or equal
	ADD R9, #1			;increment R9
	LSL R8, #1			;double R8	
	B cbp_loop_a
cbp_loop_a_exit
	SUB R0, R0, R9
	PUSH {R0}
	BX LR
	
	
flip_bit
	POP {R0}
	CMP R0, #'0'
	ITE EQ
		MOVEQ R0, #'1'
		MOVNE R0, #'0'
	PUSH {R0}
	BX LR

invalid_symbol_error
	LDR R0, =error_invalid_symbol
	PUSH {R0}
	BL write_error
	
	
;simple helper function that writes an error message. 
write_error
	POP {R0}
	LDR R1, =srcWord
write_error_loop_a
	LDRB R2, [R0], #1
	CMP R2, #0
		BEQ exit
	STRB R2, [R1], #1
	B write_error_loop_a

	ALIGN
	AREA hamming_data, DATA, READWRITE
	
max_len	EQU 100
hCode
	DCB "111111000001101", 0 ;--> 11101001101 : error corrected --> PASS
	;DCB "010011100101", 0 ;--> 11101001101 : no error --> PASS
	;DCB "011100101010", 0 ;--> 10011010 : no errors --> PASS
	;DCB "011101101010", 0 ;--> 10011010 : error corrected --> PASS
	;DCB "011101101110", 0 ;--> 10011010 : two errors --> received 10111111 --> invalid
	;DCB "001100101010", 0 ;--> 10011010 : error in parity bit 2, ignored --> PASS
	;DCB "0000000", 0 ;--> 0000 : sanity check --> PASS
	;DCB "1111111", 0 ;--> 1111 : sanity check --> PASS
	;DCB "0011111", 0 ;--> 0111 : two errors in parity bit results in a bad error correction
srcWord
	SPACE max_len
error_invalid_symbol
	DCB "INVALID SYMBOL", 0

	ALIGN
a_hCode 
	DCD hCode
a_srcWord 
	DCD srcWord

	EXPORT a_hCode
	EXPORT a_srcWord









	







	end