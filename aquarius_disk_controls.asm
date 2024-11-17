
!convtab pet

* = $801
	!byte $0b, $08 , $59, $01, $9e, $32, $30, $35, $39, $00, $a0, $00
	jmp $c201

!binary "aquarius_original.prg",,2+15

* = $c201
	jsr intro
	jsr show_image
	jsr transfer_program_to_floppy
	jsr perform_me_400
	
	; overwrite jump to $125, make it point to $200 instead
	lda #$00
	sta $82a
	lda #$02
	sta $82b
	
	; copy our code that needs to survive decompression to $200
	ldy #$00
-	lda dollar_200_code,y
	sta $200,y
	iny
	cpy #dollar_200_code_end-dollar_200_code
	bne -
	
	; replicate start of original game that we overwrote with jmp to $c201
	ldy #$00
	jmp $8d00
	
	; The game will now play it's sample and decompress/copy the next stage to $125.
	; The jump now goes to $200 instead of $125 originally

dollar_200_code:
	!pseudopc $200 {
	
	; patch jump at $140 that orginally goes to $600 to our next handler
	lda #<game_decompressed_handler
	sta $141
	lda #>game_decompressed_handler
	sta $142
	
	jmp $125 ; jump to original decompressor
	
	; the game will now do it's final decompression and jump to our game_decompressed_handler
	
game_decompressed_handler:
	; patch joy input code at  $1196
	lda #$4c ; jmp
	sta $1196
	sta $1c89
	sta $1c90
	lda #<joy_handler
	sta $1197
	lda #>joy_handler
	sta $1198
	
	; patch datasette motor control code at $1c80
	lda #<motor_off_handler
	sta $1c8a
	lda #>motor_off_handler
	sta $1c8b
	lda #<motor_on_handler
	sta $1c91
	lda #>motor_on_handler
	sta $1c92
	
	; patch text
	ldy #$00
-	lda m_text,y
	sta $6242,y
	iny
	cpy #m_text_end - m_text
	bne -
	ldy #$00
-	lda text_insert_disk,y
	sta $62ac,y
	iny
	cpy #18
	bne -

	jmp $600 ; start game

joy_handler:
	LDA $01     ; datasette key input
	AND #$10
	BEQ joy_pressed
	
	LDA $DD00    ; data line from IEC input
	AND #$80
	BEQ joy_pressed

joy_not_pressed:
	jmp $119c

joy_pressed:
	jmp $119e

motor_off_handler:
	LDA $01    ; datasette motor off
	ORA #$20
	STA $01
	lda $dd00
	and #$ef    ; IEC clock line high
	sta $dd00
	rts

motor_on_handler:
	LDA $01    ; datasette motor on
	AND #$1F
	STA $01
	lda $dd00
	ora #$10     ; IEC clock line low
	sta $dd00
	rts
	
m_text:
	!text "41 !!", $0d, $0d, $0d
text_insert_disk:
	!text "    insert disk   ", $0d, $0d, $0d
	!text "      to dive", $00
m_text_end:

	}
dollar_200_code_end:


transfer_program_to_floppy:
		LDA $BA  ; last used device number
		BNE +    ; is it 0 ?
		LDA #8   ; yes: set device 8
+		STA $BA
		LDA #<floppy_code
		STA $FB
		LDA #>floppy_code
		STA $FC
		LDA #<$400
		STA $FD
		LDA #>$400
		STA $FE
		LDA #((floppy_code_end - floppy_code -1) / 32) + 1
		STA $02 ; number of 32 byte blocks
tpf_loop:
		JSR send_mw ; Listen, send M-W
		LDA $FD
		JSR $FFA8 ; output addrlow
		LDA $FE
		JSR $FFA8 ; output addrhigh
		LDA #32
		JSR $FFA8 ; output length
		LDY #$00
-		LDA ($FB),Y
		JSR $FFA8 ; output a byte to serial bus
		INY
		CPY #32   ; 32 bytes done ?
		BCC -
		CLC
		LDA $FB
		ADC #$20
		STA $FB
		BCC +
		INC $FC
+		CLC
		LDA $FD
		ADC #$20
		STA $FD
		BCC +
		INC $FE
+		JSR $FFAE ; command serial bus to UNLISTEN
		DEC $02   ; more 32 byte blocks left?
		BNE tpf_loop ; yes: loop
		RTS

send_mw:      ; Entry M-W
		LDA #$57  
		!byte $2c
send_me:      ; Entry M-E
		LDA #$45
		PHA
		LDA $BA   ; last used device number
		JSR $FFB1 ; command device on the serial bus to LISTEN
		LDA #$6F  ; secondary address $0f | $60
		STA $B9   ; Secondary address of current file
		JSR $FF93 ; send secondary address after LISTEN
		LDA #$4D  ; 'M'
		JSR $FFA8 ; output byte to serial bus
		LDA #$2D  ; '-'
		JSR $FFA8 ; output byte to serial bus
		PLA
		JMP $FFA8 ; 'W' 'R' or 'E'
		
; Perform M-E $400
perform_me_400:
		JSR send_me ; Send M-E
		LDA #$00
		JSR $FFA8 ; output start address
		LDA #$04  ; MSB allways for $400 addresses
		JSR $FFA8
		JMP $FFAE ; command serial bus to UNLISTEN

floppy_code:
	!pseudopc $400 {
	lda #$00
	sei ; can't have any of those nasty interrupts
	
	beq skip_strong_rumble

	lda $1c00
	ora #$0c   ; motor and led on
	sta $1c00
	
	lda #35
	cmp $22
	bcs +	
	sta $22
+
-	dec $22
	beq +
	jsr track_down
	jmp -
	
+	inc $22
	
	lda #<strong_rumble
	sta rumble_option_mod  ; self modify the jsr to rumble code

skip_strong_rumble:	
	
	lda $1c00
	ora #$0c   ; original state + motor and led on
	sta $14
	and #$f3   ; original state but motor and led off
	sta $1b
	sta $1c00

	lda #$01
	sta $1d    ; reset motor timer
	
floppy_lp:
	lda $1c00
	and #$10  ; read write protect sensor
	bne +
	
	lda #$02     ; write protect: data low
	ora $1800
	bne ++  ;bra

+	lda #$fd     ; no write protect: data high
	and $1800
	
++	sta $1800
	and #$80
	bne fc_exit  ; ATN line asserted. exit.
	
rumble_option_mod = * + 1
	jsr weak_rumble
	
	jmp floppy_lp
	
fc_exit:

	lda $1b
	sta $1c00  ; restore motor / LED register

	rts

weak_rumble:
	lda $1800
	and #$04  ; clk in line
	beq +   ; high: jump +
	
	; clock is low: reset motor timer
	lda #$00
	sta $1d
	lda #$01
	
+	dec $1d
	bne wr_rumble
	inc $1d
	lda $1b
	sta $1c00  ; motor and led off after timeout
	rts
wr_rumble:
              ; A still holds 1 if clock is low or 0 if clock is high
	eor $14   ; original state with motor and led on, toggle stepper phase through bit 0 with rumble input
	sta $1c00
	rts

strong_rumble:
	lda $1d    ; $1d != 0: running
	bne sr_run
	
	lda $1800
	and #$04  ; clk in line
	beq sr_exit   ; high: nothing to do
	
	; clock is low: reset timer
	lda #$00
	sta $1d	
	
sr_run:
	lda $1c00
	ora #$0c   ; motor and led on
	sta $1c00
		
	lda $1d
	and #$3f
	bne +     ; trigger on 00 c0 80 40 while counting down
	jsr half_track_down
+	dec $1d
	rts

sr_exit:
	lda $1c00
	and #$f3   ; motor and led off
	sta $1c00
	rts
	
+	dec $1d
	bne sr_rumble
	inc $1d
	lda $1b
	sta $1c00  ; motor and led off after timeout
	rts
sr_rumble:
              ; A still holds 1 if clock is low or 0 if clock is high
	eor $14   ; original state with motor and led on, toggle stepper phase through bit 0 with rumble input
	sta $1c00
	rts

track_down:
		JSR half_track_down
		jsr delay
		JSR half_track_down
		jsr delay
		rts

half_track_down:
		LDX $1C00
		DEX
		TXA
		AND #$03
		STA $44
		LDA $1C00
		AND #$FC
		ORA $44
		STA $1C00
		rts

delay:
		LDY #$06 ; delay
delay_y:
--		LDX #$00
-		DEX
		BNE -
		DEY
		BNE --
		RTS

	}
floppy_code_end:

intro:
	lda #$00
	sta $d020
	sta $d021
	jsr $e544 ; clear the screen
		
	lda #<intro_text
	sta $fb
	ldy #>intro_text
	sty $fc
	
	jsr print
	
	lda #$0
	sta $fd ; reset color cycle

	ldy #1
	
intro_loop:
	JSR $FFE4 ; get character from input device
	cmp #' '
	bne +
	rts

+	cmp #$85 ; F1
	bne +
	
	lda #$01
	sta floppy_code+1 ; enable hard rumble
	rts
	
+	jsr cycle_colors
	jsr cycle_amazing_colors

-	lda $d011    ; wating for raster line lower than 256
	and #$80
	bne -

-	lda $d011    ; wating for raster line 256
	and #$80
	beq -
		
	jmp intro_loop
	
	rts

print:
-	ldy #$00
	lda ($fb),y
	beq +
	jsr $ffd2
	inc $fb
	bne -
	inc $fc
	jmp -
+	rts

cycle_colors:
	lda $fd
	lsr
	tay
	lda color_table_2,y
	lda color_table_2,y
	
	LDX #120
-	STA $D800,X
	STA $D800 + 21*40,X
	DEX
	BNE -
	
	inc $fd
	lda $fd
	cmp # (color_table_2_end - color_table_2) * 2
	bne cc_exit
	lda #0
	sta $fd

cc_exit:
	rts
	
fill_color_line:
	ldy #39
-	sta ($fb),y
	dey
	bpl -
	lda $fb
	clc
	adc #40
	sta $fb
	bcc +
	inc $fc
+	rts

get_color:
	clc
	lda $02
	adc $2a
	lsr
	lsr
	lsr
	jmp +

	; mod 6
-	sbc #6	
+	cmp #6
	bcs -

	tay
	lda color_table_1,y
	rts

cycle_amazing_colors:
	; $fb fc to color ram at line 4
	lda #<($d800 + 40*4)
	sta $fb
	lda #>($d800 + 40*4)
	sta $fc
	
	lda #$00
	sta $02
	
-	jsr get_color	
	jsr fill_color_line
	inc $02
	inc $02
	lda #16*2
	cmp $02
	bne -
	
	inc $2a
	lda #48
	cmp $2a
	bne +
	lda #$00
	sta $2a
	
+	rts

color_table_1: !byte 7, 10, 8, 9, 8, 10
color_table_1_end:

color_table_2:
	; white flashing
	!byte 1, 15, 12, 11, 12, 15
color_table_2_end:

	
intro_text:
	!text $0e ; lowercase
	!text " Aquarius was ported from datasette to", $0d
    !text "	diskdrive by TIXIV from DIENSTAGSTREFF", $0d
	!text "      on the 15th of November 2024", $0d, $0d
	
	!text " Now finally diskdrive owners can also", $0d
	!text "       play this amazing game!", $0d, $0d
	
	!text "    Remove and half insert your disk", $0d
	!text "  so that the write protect sensor gets", $0d
	!text "triggered by the disk's front edge when", $0d
	!text "   you push it in a little further.", $0d, $0d
	
	!text " The haptic feedback is weak by default."
	!text " you can press F1 instead of space for", $0d
	!text " harder haptic feedback, but that will", $0d
	!text "  knock the 1541's head to the 0 stop.", $0d, $0d
	
	!text "    I find clamping the 1541 between", $0d
	!text "  my legs while sitting gives the best", $0d
	!text "    gaming experience. See fig. 1", $0d, $0d, $0d

	!text "    PRESS SPACE OR F1 TO CONTINUE", $08, $0e, $00 ; lowercase, disable switching font


show_image:
	lda #$00
	sta $d020
	sta $d021
	
	lda $dd00
	and #$fC   ; VIC bank 3
	STA $DD00
	
	LDA #$3B  ; Bitmap mode, screen on, 25 rows
	STA $D011
	LDA #$48  ; Bitmap memory at $e000-$ffff, screen memory $D000-$D3ff
	STA $D018
	LDA #$18
	STA $D016 ; muti color, 40 columns
		
	LDX #$FA
-	LDA pict_color_ram,X
	STA $D800,X
	LDA pict_color_ram+250,X
	STA $D8FA,X
	LDA pict_color_ram+500,X
	STA $D9F4,X
	LDA pict_color_ram+750,X
	STA $DAEE,X
	DEX
	BNE -
	
-	JSR $FFE4 ; get character from input device
	cmp #' '
	bne -
	rts

* = $d000 - $3e8
pict_color_ram:
	!binary "picture.prg",$3e8,$fe8-$7ff

* = $d000
	!binary "picture.prg",$3e8,$c00-$7ff

* = $e000
	!binary "picture.prg",$1f42,$2000-$7ff


	

	
	