/* x86_64 Limine entry: enable the baseline SIMD/FPU state before Zig code. */
.text
.globl _start
.type _start, @function
_start:
    cli
    cld
    movq %cr0, %rax
    andq $~0x0c, %rax       /* Clear EM and TS. */
    orq $0x02, %rax         /* Set MP. */
    movq %rax, %cr0
    movq %cr4, %rax
    orq $0x600, %rax        /* OSFXSR | OSXMMEXCPT. */
    movq %rax, %cr4
    fninit
    andq $-16, %rsp         /* Align the stack for the System V kernel ABI. */
    call kratos_kernel_main
.Lhalt:
    hlt
    jmp .Lhalt
.size _start, .-_start

.section .note.GNU-stack,"",@progbits
