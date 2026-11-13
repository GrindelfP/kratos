/* Single-CPU test boundary. Maskable interrupts remain disabled throughout. */
.text
.globl kratos_enable_nx
kratos_enable_nx:
    pushq %rbx
    movl $0x80000000, %eax
    cpuid
    cmpl $0x80000001, %eax
    jb 2f
    movl $0x80000001, %eax
    cpuid
    btl $20, %edx
    jnc 2f
    movl $0xc0000080, %ecx
    rdmsr
    orl $0x800, %eax
    wrmsr
    movl $1, %eax
    popq %rbx
    ret
2:  xorl %eax, %eax
    popq %rbx
    ret
.globl kratos_user_setup
kratos_user_setup:
    leaq user_tss(%rip), %rax
    movw $103, user_gdt+40(%rip)
    movw %ax, user_gdt+42(%rip)
    shrq $16, %rax
    movb %al, user_gdt+44(%rip)
    movb $0x89, user_gdt+45(%rip)
    movb $0, user_gdt+46(%rip)
    movb %ah, user_gdt+47(%rip)
    shrq $16, %rax
    movl %eax, user_gdt+48(%rip)
    leaq user_kernel_stack_end(%rip), %rax
    movq %rax, user_tss+4(%rip)
    movw $104, user_tss+102(%rip) /* no I/O bitmap */
    lgdt user_gdtr(%rip)
    pushq $8
    leaq 1f(%rip), %rax
    pushq %rax
    lretq
1:  movw $16, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movw $40, %ax
    ltr %ax
    ret

/* rdi=new CR3, rsi=user RIP, rdx=user RSP. */
.globl kratos_user_enter
kratos_user_enter:
    pushq %rbx
    pushq %rbp
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    movq %rsp, user_saved_rsp(%rip)
    movq %cr3, %rax
    movq %rax, user_saved_cr3(%rip)
    movq %cr4, %rax
    movq %rax, user_saved_cr4(%rip)
    andq $~0x80, %rax        /* flush global TLB entries too */
    movq %rax, %cr4
    movq %rdi, %cr3
    pushq $0x1b
    pushq %rdx
    pushq $2                 /* IF=0, IOPL=0 */
    pushq $0x23
    pushq %rsi
    iretq

/* Called only from a proven user-origin exception, with interrupts disabled. */
.globl kratos_user_recover
kratos_user_recover:
    movq user_saved_cr3(%rip), %rax
    movq %rax, %cr3
    movq user_saved_cr4(%rip), %rax
    movq %rax, %cr4
    movq user_saved_rsp(%rip), %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbp
    popq %rbx
    ret

/* Position-independent snippets copied to user code. Record actual CS first. */
.globl kratos_user_ud_begin, kratos_user_ud_end
kratos_user_ud_begin:
    pushq $0x1234            /* exercise the user stack */
    popq %rcx
    movabsq $0x401000, %rax
    movw %cs, (%rax)
    ud2
kratos_user_ud_end:
.globl kratos_user_pf_begin, kratos_user_pf_end
kratos_user_pf_begin:
    movabsq $0x401000, %rax
    movw %cs, (%rax)
    movabsq $0xffffffff80000000, %rax
    movq (%rax), %rax
    ud2
kratos_user_pf_end:
.globl kratos_user_write_begin, kratos_user_write_end
kratos_user_write_begin:
    movabsq $0x401000, %rax
    movw %cs, (%rax)
    movabsq $0x400000, %rax
    movb $0, (%rax)
    ud2
kratos_user_write_end:
.globl kratos_user_nx_begin, kratos_user_nx_end
kratos_user_nx_begin:
    movabsq $0x401000, %rax
    movw %cs, (%rax)
    movabsq $0x401100, %rax
    jmp *%rax
kratos_user_nx_end:

.data
.align 8
user_gdt:
    .quad 0
    .quad 0x00af9a000000ffff /* kernel code */
    .quad 0x00cf92000000ffff /* kernel data */
    .quad 0x00cff2000000ffff /* user data */
    .quad 0x00affa000000ffff /* user code */
    .quad 0, 0              /* TSS */
user_gdt_end:
user_gdtr:
    .word user_gdt_end-user_gdt-1
    .quad user_gdt
.bss
.align 16
user_tss: .skip 104
user_saved_rsp: .skip 8
user_saved_cr3: .skip 8
user_saved_cr4: .skip 8
.align 16
user_kernel_stack: .skip 16384
user_kernel_stack_end:
.section .note.GNU-stack,"",@progbits
