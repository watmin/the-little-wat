# elf/runtime.s -- the six routines elf/compile.wat embeds as hex.
#
# This file is the SOURCE for that hex, kept so the block can be read and re-derived rather than
# trusted. The compiler does not read it; `:c::rt-*` in elf/compile.wat hold the assembled bytes.
#
# To regenerate:
#     as --64 -o /tmp/rt.o elf/runtime.s
#     objcopy -O binary --only-section=.text /tmp/rt.o /tmp/rt.bin
#     objdump -r /tmp/rt.o        # MUST show no relocations -- see below
#     nm -n /tmp/rt.o             # the six offsets, which must match :c::at-* in compile.wat
#
# The symbols are deliberately NOT .globl. With `.globl`, `as` leaves each internal `call` as a
# relocation (`e8 00000000`) for a linker that never runs here, and `objcopy` does not apply
# them -- the calls then jump to the next instruction and quietly unbalance the stack. That
# happened, and the binary printed nothing at all.
#
# The order matters: the block is concatenated in this order and the offsets are computed from
# the lengths, so the internal calls only line up if nothing is reordered.
#
.text
# ---- r14 = [used:8][4096 bytes] output buffer;  r15 = heap bump pointer

print_i64:                       # rax = value
    push %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    leaq -1(%rbp), %rsi
    movb $10, (%rsi)             # the newline goes in first, at the top
    xorq %r8, %r8
    testq %rax, %rax
    jns 1f
    negq %rax
    movq $1, %r8                 # remember the sign and remove it
1:  movq $10, %rcx
2:  xorq %rdx, %rdx
    divq %rcx
    addb $48, %dl
    decq %rsi
    movb %dl, (%rsi)             # digits backwards, on the stack
    testq %rax, %rax
    jnz 2b
    testq %r8, %r8
    jz 3f
    decq %rsi
    movb $45, (%rsi)             # put the sign back
3:  leaq -1(%rbp), %rdx
    subq %rsi, %rdx
    incq %rdx
    call buf_put
    leave
    ret

str_cat:                         # rax = a, rcx = b  ->  rax
    movq (%rax), %r8
    movq (%rcx), %r9
    leaq 8(%rax), %rdx
    leaq 8(%rcx), %rcx
    movq %r8, %rax
    addq %r9, %rax
    movq %rax, (%r15)            # the new header
    movq %r15, %r10
    leaq 8(%r15), %rdi
    addq $15, %rax
    andq $-8, %rax
    addq %rax, %r15              # bump, rounded up to eight
    movq %rdx, %rsi
    movq %r8, %r11
1:  testq %r11, %r11
    jz 2f
    movb (%rsi), %al
    movb %al, (%rdi)
    incq %rsi
    incq %rdi
    decq %r11
    jmp 1b
2:  movq %rcx, %rsi
    movq %r9, %r11
3:  testq %r11, %r11
    jz 4f
    movb (%rsi), %al
    movb %al, (%rdi)
    incq %rsi
    incq %rdi
    decq %r11
    jmp 3b
4:  movq %r10, %rax
    ret

print_str:                       # rax = string, rendered as EDN
    movq %rax, %r8
    movq (%r8), %r9
    leaq 8(%r8), %rsi
    movq %r15, %rdi              # scratch at the heap top; r15 is NOT bumped
    movq %r15, %r10
    movb $0x22, (%rdi)
    incq %rdi
    xorq %r11, %r11
1:  cmpq %r9, %r11
    jge 9f
    movb (%rsi), %al
    cmpb $0x22, %al
    je 2f
    cmpb $0x5c, %al
    je 2f
    cmpb $0x0a, %al
    je 3f
    cmpb $0x09, %al
    je 4f
    cmpb $0x0d, %al
    je 5f
    movb %al, (%rdi)
    incq %rdi
    jmp 8f
2:  movb $0x5c, (%rdi)
    incq %rdi
    movb %al, (%rdi)
    incq %rdi
    jmp 8f
3:  movb $0x5c, (%rdi)
    incq %rdi
    movb $0x6e, (%rdi)
    incq %rdi
    jmp 8f
4:  movb $0x5c, (%rdi)
    incq %rdi
    movb $0x74, (%rdi)
    incq %rdi
    jmp 8f
5:  movb $0x5c, (%rdi)
    incq %rdi
    movb $0x72, (%rdi)
    incq %rdi
8:  incq %rsi
    incq %r11
    jmp 1b
9:  movb $0x22, (%rdi)
    incq %rdi
    movb $0x0a, (%rdi)
    incq %rdi
    movq %rdi, %rdx
    subq %r10, %rdx
    movq %r10, %rsi
    call buf_put
    ret

print_bool:                      # rax = 0 or 1
    push %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    testq %rax, %rax
    jz 1f
    movl $0x65757274, -8(%rbp)   # "true"
    movb $0x0a, -4(%rbp)
    movq $5, %rdx
    jmp 2f
1:  movl $0x736c6166, -8(%rbp)   # "fals"
    movw $0x0a65, -4(%rbp)       # "e\n"
    movq $6, %rdx
2:  leaq -8(%rbp), %rsi
    call buf_put
    leave
    ret

buf_put:                         # rsi = bytes, rdx = count
    movq (%r14), %rax            # how much is already in the buffer
    leaq (%rax,%rdx), %rcx
    cmpq $4096, %rcx
    jbe 2f
    push %rsi
    push %rdx
    call flush
    pop %rdx
    pop %rsi
    cmpq $4096, %rdx
    jbe 1f
    movq $1, %rdi                # too big for an empty buffer: write it straight out
    movq $1, %rax
    syscall
    ret
1:  xorq %rax, %rax
2:  leaq 8(%r14), %rdi
    addq %rax, %rdi
    addq %rdx, (%r14)
    movq %rdx, %rcx
    rep movsb
    ret

flush:                           # write whatever is buffered, and empty it
    movq (%r14), %rdx
    testq %rdx, %rdx
    jz 1f
    leaq 8(%r14), %rsi
    movq $1, %rdi
    movq $1, %rax
    syscall
    movq $0, (%r14)
1:  ret
