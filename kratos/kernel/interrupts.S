/* Minimal x86-64 exception entry boundary. The C ABI call is aligned before
 * entering Zig; all general-purpose registers are preserved. The dispatcher
 * either halts or abandons the frame via the bounded user recovery path.
 */
.text
.extern kratos_exception_dispatch

.macro EXCEPTION_NOERR n
.globl kratos_exception_\n
kratos_exception_\n:
    pushq $0
    pushq $\n
    jmp kratos_exception_common
.endm

.macro EXCEPTION_ERR n
.globl kratos_exception_\n
kratos_exception_\n:
    /* CPU already pushed the architectural error code. */
    pushq $\n
    jmp kratos_exception_common
.endm

/* Exceptions that push an error code in 64-bit mode: #DF, #TS, #NP, #SS,
 * #GP, #PF, #AC, #CP, #VC, and #SX. */
EXCEPTION_NOERR 0
EXCEPTION_NOERR 1
EXCEPTION_NOERR 2
EXCEPTION_NOERR 3
EXCEPTION_NOERR 4
EXCEPTION_NOERR 5
EXCEPTION_NOERR 6
EXCEPTION_NOERR 7
EXCEPTION_ERR   8
EXCEPTION_NOERR 9
EXCEPTION_ERR   10
EXCEPTION_ERR   11
EXCEPTION_ERR   12
EXCEPTION_ERR   13
EXCEPTION_ERR   14
EXCEPTION_NOERR 15
EXCEPTION_NOERR 16
EXCEPTION_ERR   17
EXCEPTION_NOERR 18
EXCEPTION_NOERR 19
EXCEPTION_NOERR 20
EXCEPTION_ERR   21
EXCEPTION_NOERR 22
EXCEPTION_NOERR 23
EXCEPTION_NOERR 24
EXCEPTION_NOERR 25
EXCEPTION_NOERR 26
EXCEPTION_NOERR 27
EXCEPTION_NOERR 28
EXCEPTION_ERR   29
EXCEPTION_ERR   30
EXCEPTION_NOERR 31

kratos_exception_common:
    cld
    pushq %rax
    pushq %rcx
    pushq %rdx
    pushq %rbx
    pushq %rbp
    pushq %rsi
    pushq %rdi
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    movq 120(%rsp), %rdi       /* vector, below 15 saved registers */
    movq 128(%rsp), %rsi       /* error code */
    movq 136(%rsp), %rdx       /* interrupted instruction pointer */
    movq 144(%rsp), %rcx       /* interrupted code selector */
    movq %rsp, %r12
    andq $-16, %rsp
    call kratos_exception_dispatch
    ud2

.section .rodata
.align 8
.globl kratos_exception_stub_table
kratos_exception_stub_table:
.quad kratos_exception_0,  kratos_exception_1,  kratos_exception_2,  kratos_exception_3
.quad kratos_exception_4,  kratos_exception_5,  kratos_exception_6,  kratos_exception_7
.quad kratos_exception_8,  kratos_exception_9,  kratos_exception_10, kratos_exception_11
.quad kratos_exception_12, kratos_exception_13, kratos_exception_14, kratos_exception_15
.quad kratos_exception_16, kratos_exception_17, kratos_exception_18, kratos_exception_19
.quad kratos_exception_20, kratos_exception_21, kratos_exception_22, kratos_exception_23
.quad kratos_exception_24, kratos_exception_25, kratos_exception_26, kratos_exception_27
.quad kratos_exception_28, kratos_exception_29, kratos_exception_30, kratos_exception_31

.section .note.GNU-stack,"",@progbits
