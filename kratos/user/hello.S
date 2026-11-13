/* Flat image: 12-byte header, followed by position-independent code and data. */
.section .text
.ascii "KRU1"
.long image_end - code_start
.long 0
code_start:
    movq $1, %rax
    leaq message(%rip), %rdi
    movq $message_end-message, %rsi
    int $0x80
    movq $2, %rax
    movq $7, %rdi
    int $0x80
    ud2
message: .ascii "Hello from a separate user program!\r\n"
message_end:
image_end:
.section .note.GNU-stack,"",@progbits
