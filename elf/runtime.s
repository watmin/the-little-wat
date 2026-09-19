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
# ---- r14 = [used:8][heap_limit:8][4096 bytes] ;  r15 = heap bump pointer
#
# The heap limit lives beside the output buffer because there is no third callee-saved register
# to spare and no writable data section to put it in. Every allocator checks against it BEFORE
# it writes anything, so running out of memory is a message rather than a segmentation fault.

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
    addq $23, %rax
    andq $-8, %rax               # 8 rc + 8 length + total, rounded up to eight
    movq %r15, %r11
    addq %rax, %r11
    cmpq 8(%r14), %r11
    jbe 9f
    call oom
9:  movq $1, (%r15)              # rc = 1
    leaq 8(%r15), %r10           # the pointer is the word after the rc
    movq %r8, %rax
    addq %r9, %rax
    movq %rax, (%r10)            # the new length
    leaq 8(%r10), %rdi
    movq %r11, %r15
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
2:  leaq 16(%r14), %rdi
    addq %rax, %rdi
    addq %rdx, (%r14)
    movq %rdx, %rcx
    rep movsb
    ret

flush:                           # write whatever is buffered, and empty it
    movq (%r14), %rdx
    testq %rdx, %rdx
    jz 1f
    leaq 16(%r14), %rsi
    movq $1, %rdi
    movq $1, %rax
    syscall
    movq $0, (%r14)
1:  ret

# ---- every heap object carries a reference count in the word BELOW the pointer, so that all the
# payload offsets stay where they were: `[rc:8]` at [p-8], then [count:8] at [p], then the slots.
# The count is INCREMENT-ONLY -- it is never decremented, so it answers exactly one question:
# "has this pointer ever been stored anywhere durable?" A count of 1 means no, and that is the
# only thing an in-place update needs to know about aliasing. Never decrementing means the answer
# can only get more conservative, never wrong.
#
# ---- vectors and records share one layout: [count:8][slot:8]... , every slot a machine word.
# So `length` is a peek at the header for a String, a Vector and a record alike, and `nth` and a
# field access are the same indexed load.

vec_new:                         # rax = count  ->  rax = vector, slots uninitialised
    leaq 16(,%rax,8), %rcx       # 8 rc + 8 count + 8n
    movq %r15, %r11
    addq %rcx, %r11
    cmpq 8(%r14), %r11           # check BEFORE writing anything
    jbe 1f
    call oom
1:  movq $1, (%r15)              # rc = 1
    leaq 8(%r15), %r10           # the pointer is the word AFTER the count
    movq %rax, (%r10)
    movq %r11, %r15
    movq %r10, %rax
    ret

# `vec_conj_own` is `conj` where the COMPILER has proved the container is a last use -- no later
# read of that variable can observe a change. That plus a reference count of 1 (never stored
# anywhere durable) plus being the top of the heap is enough to extend in place, which is what
# turns an accumulator loop from O(n^2) into O(n). It is Rust's `Vec::push` and Clojure's
# transient, arrived at from the two halves neither implementation has alone: the count rules out
# aliases, last-use rules out later reads.
vec_conj_own:                    # rax = vector (proved dead after this), rcx = element
    cmpq $1, -8(%rax)            # ever stored anywhere?
    jne vec_conj
    movq (%rax), %r8
    leaq 8(%rax,%r8,8), %rdx     # one past the last slot
    cmpq %r15, %rdx              # is this object still the top of the heap?
    jne vec_conj
    movq %r15, %r11
    addq $8, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq %rcx, (%r15)            # the new element goes exactly where r15 points
    movq %r11, %r15
    leaq 1(%r8), %rdx
    movq %rdx, (%rax)
    ret

vec_conj:                        # rax = vector, rcx = element  ->  rax = a longer copy
    movq %rcx, %r10              # the element, before rcx becomes the copy count
    movq (%rax), %r8
    leaq 24(,%r8,8), %rdx        # 8 rc + 8 count + 8(n+1)
    movq %r15, %r11
    addq %rdx, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $1, (%r15)              # rc = 1
    leaq 8(%r15), %r9
    leaq 1(%r8), %rdx
    movq %rdx, (%r9)             # new count
    leaq 8(%r9), %rdi
    leaq 8(%rax), %rsi
    movq %r8, %rcx
    rep movsq
    movq %r10, (%rdi)            # and the new element on the end
    movq %r11, %r15
    movq %r9, %rax
    ret

slot_set:                        # rax = vector/record, rcx = index, rdx = value -> rax = a copy
    movq (%rax), %r8             # with that one slot replaced; this is `assoc`
    movq %r15, %r11
    leaq 16(,%r8,8), %r10
    addq %r10, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $1, (%r15)              # rc = 1
    leaq 8(%r15), %r9
    movq %r8, (%r9)
    leaq 8(%r9), %rdi
    leaq 8(%rax), %rsi
    movq %rcx, %r10
    movq %rdx, %rbx
    movq %r8, %rcx
    rep movsq
    movq %r11, %r15
    movq %r9, %rax
    movq %rbx, 8(%rax,%r10,8)
    ret

oom:                             # no memory left: say so on stderr rather than fault
    call flush                   # whatever stdout had buffered is still worth having
    subq $32, %rsp
    movabsq $0x616568203a746177, %rax    # "wat: hea"
    movq %rax, (%rsp)
    movabsq $0x7375616878652070, %rax    # "p exhaus"
    movq %rax, 8(%rsp)
    movl $0x0a646574, %eax               # "ted\n"
    movl %eax, 16(%rsp)
    movq $2, %rdi
    movq %rsp, %rsi
    movq $20, %rdx
    movq $1, %rax
    syscall
    movq $70, %rdi
    movq $60, %rax
    syscall
