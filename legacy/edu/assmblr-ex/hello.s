.section __TEXT,__text
.globl _main

_main:
	leaq message(%rip), %rdi  
	movq $length, %rsi        
	movq $0x2000004, %rax	 
	movq $1, %rdx           
	syscall

	movq $0x2000001, %rax
	movq $0, %rdi
	syscall

.section __DATA,__data
message:
	.asciz "Oh, shit, here we go again! Hello from assembly!\n"
length = .-message

