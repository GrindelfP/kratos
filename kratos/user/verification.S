/* Test-only KRU1 images; selected at build time, never by untrusted input. */
.section .text
.ascii "KRU1"
.long image_end - code_start
.long 0
code_start:
#if TEST_CASE == 1
    movq $1, %rax
    movabsq $0xffff800000000000, %rdi
    movq $1, %rsi
    int $0x80
    cmpq $-1, %rax
    jne failed
    movq $999, %rax
    int $0x80
    cmpq $-3, %rax
    jne failed
    movq $2, %rax
    movq $21, %rdi
    int $0x80
failed:
    movq $2, %rax
    movq $99, %rdi
    int $0x80
#elif TEST_CASE == 2
    ud2
#elif TEST_CASE == 3
    movabsq $0xffff800000000000, %rax
    movq (%rax), %rax
#elif TEST_CASE == 4
    movb $0, 0x400000
#elif TEST_CASE == 5
    movabsq $0x401000, %rax
    jmp *%rax
#else
#error unknown verification case
#endif
    ud2
image_end:
.section .note.GNU-stack,"",@progbits
