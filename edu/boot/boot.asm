; boot file

BITS 16

org 0x7C00

jmp start

start:
	mov ax, 0 
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00

	jmp 0x1000:0x0000

times 510-($-$$) db 0
dw 0xAA55

