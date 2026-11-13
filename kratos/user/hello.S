/* Flat image: the first package reads its message through the file syscalls. */
.section .text
.ascii "KRU1"
.long image_end - code_start
.long 0
code_start:
    movq $3, %rax
    leaq path(%rip), %rdi
    movq $path_end-path, %rsi
    int $0x80
    testq %rax, %rax
    js failed
    movq %rax, %r12
    movq $4, %rax
    movq %r12, %rdi
    movabsq $0x400fff, %rsi
    movq $2, %rdx
    int $0x80
    cmpq $-1, %rax
    jne failed_close
    movq $4, %rax
    movq %r12, %rdi
    movabsq $0x401000, %rsi
    movq $513, %rdx
    int $0x80
    cmpq $-2, %rax
    jne failed_close
    movq $3, %rax
    movabsq $0xffffffff80000000, %rdi
    movq $1, %rsi
    int $0x80
    cmpq $-1, %rax
    jne failed_close
    movq $4, %rax
    movq %r12, %rdi
    movabsq $0x401000, %rsi
    movq $512, %rdx
    int $0x80
    testq %rax, %rax
    js failed_close
    movq %rax, %r13
    movq $5, %rax
    movq %r12, %rdi
    int $0x80
    movq $4, %rax
    movq %r12, %rdi
    movabsq $0x401000, %rsi
    movq $1, %rdx
    int $0x80
    cmpq $-6, %rax
    jne failed
    movq $3, %rax
    movabsq $0x400000, %rdi
    movq $1, %rsi
    int $0x80
    cmpq $-1, %rax
    jne failed
    movq $3, %rax
    leaq missing_path(%rip), %rdi
    movq $missing_path_end-missing_path, %rsi
    int $0x80
    cmpq $-4, %rax
    jne failed
    movq $1, %rax
    movabsq $0x401000, %rdi
    movq %r13, %rsi
    int $0x80
    movq $2, %rax
    movq $7, %rdi
    int $0x80
failed_close:
    movq $5, %rax
    movq %r12, %rdi
    int $0x80
failed:
    movq $2, %rax
    movq $99, %rdi
    int $0x80
    ud2
path: .ascii "system:/packages/hello/message"
path_end:
missing_path: .ascii "system:/missing"
missing_path_end:
image_end:
.section .note.GNU-stack,"",@progbits
