.section __TEXT,__text
.globl _main

_main:
	movq $0x2000001, %rax
	movq $0, %rdi
	syscall

