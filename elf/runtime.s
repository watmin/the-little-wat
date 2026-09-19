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



# ---- i64 traps, so the compiled language must trap too.
#
# wat's `+` answers `IntegerOverflow: ... does not fit in 64 bits` and stops the program. This
# compiler emitted a bare `add rax, rcx` and wrapped -- `(+ 9223372036854775807 1)` printed
# -9223372036854775808 and exited 0 where the interpreter died. **A wrong answer, not a
# refusal**, and nothing in forty programs overflowed, so nothing caught it (F-125).
#
# Every `+`, `-` and `*` now carries `jo` to here. The branch is never taken and predicts as
# such; the cost is six bytes at each arithmetic site and nothing at run time.
ovf:                             # signed overflow: say which, and stop
    call flush                   # whatever stdout had buffered is still worth having
    subq $32, %rsp
    movabsq $0x343669203a746177, %rax    # "wat: i64"
    movq %rax, (%rsp)
    movabsq $0x6f6c667265766f20, %rax    # " overflo"
    movq %rax, 8(%rsp)
    movl $0x000a77, %eax                 # "w\n"
    movl %eax, 16(%rsp)
    movq $2, %rdi
    movq %rsp, %rsi
    movq $18, %rdx
    movq $1, %rax
    syscall
    movq $70, %rdi
    movq $60, %rax
    syscall



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



die:                             # rax = String  ->  it on stderr, then exit 70
    movq %rax, %r10
    call flush                   # anything stdout had buffered is still worth having
    movq (%r10), %rdx
    leaq 8(%r10), %rsi
    movq $2, %rdi
    movq $1, %rax
    syscall
    subq $8, %rsp
    movb $10, (%rsp)
    movq $2, %rdi
    movq %rsp, %rsi
    movq $1, %rdx
    movq $1, %rax
    syscall
    movq $70, %rdi
    movq $60, %rax
    syscall



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



# `str_cat(rax = a, rcx = b) -> rax`: the two lengths added, a header written at the heap top,
# both payloads copied, r15 bumped past the whole block. The block is the next power of two at
# or above `16 + len`, which is what gives the in-place path above room to grow into. The slack
# is never more than the string itself, and it is what turns an append loop into O(n).
str_cat:                         # rax = a, rcx = b  ->  rax
    movq (%rax), %r8             # len a
    movq (%rcx), %r9             # len b
    leaq 8(%rax), %r10           # a's bytes
    leaq 8(%rcx), %r11           # b's bytes
    movq %r8, %rax
    addq %r9, %rax               # the new length
    leaq 15(%rax), %rdx
    bsrq %rdx, %rcx
    movq $2, %rdx
    shlq %cl, %rdx               # 8 rc + 8 len + bytes, rounded up to a power of two
    movq %r15, %rcx
    addq %rdx, %rcx
    cmpq 8(%r14), %rcx           # check BEFORE writing anything
    jbe 1f
    call oom
1:  movq $1, (%r15)              # rc = 1
    leaq 8(%r15), %rdx           # the pointer is the word after the rc
    movq %rax, (%rdx)            # the new length
    movq %rcx, %r15              # the whole block is reserved, slack included
    leaq 8(%rdx), %rdi
    movq %r10, %rsi
    movq %r8, %rcx
    rep movsb                    # a's bytes
    movq %r11, %rsi
    movq %r9, %rcx
    rep movsb                    # then b's
    movq %rdx, %rax
    ret



# `str_cat_own` is `concat` where the compiler has proved the left operand is a last use -- the
# same two proofs `vec_conj_own` needs, for the accumulator `:c::emit` is built out of.
#
# A String is `[rc:8][len:8][bytes]` inside a block whose size is ALWAYS the next power of two
# at or above `16 + len`. That makes the spare room derivable from the length alone, with no
# header field to carry it, so appending in place is legal whenever the new length still fits
# the block -- WHEREVER the string sits in the heap. The rule before this one also demanded the
# string be the TOP of the heap, which is what a bump allocator needs to EXTEND an object; that
# made the fast path conditional on nothing else having allocated since, which is true of a
# microbenchmark and false of `:c::emit`. elf/bench/catx.wat is the measurement: one growing
# accumulator 2,180 KiB, the same appends with a second one beside it 1,855,368 KiB.
str_cat_own:                     # rax = a (proved dead after this), rcx = b  ->  rax
    cmpq $1, -8(%rax)            # ever stored anywhere? a literal is 0, a shared value is > 1
    {disp32} jne str_cat        # 32-bit, so it still reaches when the layout changes
    movq %rcx, %r9               # park b: rcx is about to be a shift count
    movq (%rax), %r8             # len a
    movq (%r9), %r10             # len b
    movq %r8, %r11
    addq %r10, %r11              # the new length
    leaq 15(%r8), %rdx           # (16 + len a) - 1
    bsrq %rdx, %rcx
    movq $2, %rdi
    shlq %cl, %rdi               # 2 << bsr(n-1) is the next power of two at or above n
    leaq 16(%r11), %rdx
    cmpq %rdi, %rdx              # does the new length still fit a's block?
    ja 8f
    movq %r11, (%rax)            # it does: the new length, and the bytes straight on the end
    leaq 8(%rax,%r8), %rdi
    leaq 8(%r9), %rsi
    movq %r10, %rcx
    rep movsb
    ret
8:  movq %r9, %rcx               # it does not: copy into a block of the next size up
    {disp32} jmp str_cat



# ---- the string verbs a reader needs. All of them work on [rc:8][len:8][bytes], so none of them
# needs to know anything the rest of the runtime does not already know.

str_subs:                        # rax = s, rcx = from, rdx = to  ->  rax = a new String
    movq %rdx, %r8
    subq %rcx, %r8               # the new length
    leaq 8(%rax,%rcx), %rdi      # the source bytes, taken before rcx becomes a shift count
    leaq 15(%r8), %rdx
    bsrq %rdx, %rcx
    movq $2, %r9
    shlq %cl, %r9                # 8 rc + 8 len + bytes, rounded up to a power of two
    movq %r15, %r11
    addq %r9, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $1, (%r15)
    leaq 8(%r15), %r10
    movq %r8, (%r10)
    movq %rdi, %rsi
    leaq 8(%r10), %rdi
    movq %r11, %r15
    movq %r8, %rcx
    rep movsb
    movq %r10, %rax
    ret



i64_to_str:                      # rax = n  ->  rax = a new String
    push %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    movq %rbp, %rsi              # digits are written backwards from here
    xorq %r8, %r8
    testq %rax, %rax
    jns 1f
    negq %rax
    movq $1, %r8
1:  movq $10, %rcx
2:  xorq %rdx, %rdx
    divq %rcx
    addb $48, %dl
    decq %rsi
    movb %dl, (%rsi)
    testq %rax, %rax
    jnz 2b
    testq %r8, %r8
    jz 3f
    decq %rsi
    movb $45, (%rsi)
3:  movq %rbp, %r9
    subq %rsi, %r9               # how many characters that was
    leaq 15(%r9), %r10
    bsrq %r10, %rcx
    movq $2, %r10
    shlq %cl, %r10               # 8 rc + 8 len + bytes, rounded up to a power of two
    movq %r15, %r11
    addq %r10, %r11
    cmpq 8(%r14), %r11
    jbe 4f
    call oom
4:  movq $1, (%r15)
    leaq 8(%r15), %r10
    movq %r9, (%r10)
    leaq 8(%r10), %rdi
    movq %r11, %r15
    movq %r9, %rcx
    rep movsb
    movq %r10, %rax
    leave
    ret



str_starts:                      # rax = s, rcx = prefix  ->  rax = 0 or 1
    movq (%rcx), %r8
    cmpq (%rax), %r8
    jg 9f                        # a prefix longer than the string is never one
    leaq 8(%rax), %rsi
    leaq 8(%rcx), %rdi
    movq %r8, %rcx
    testq %rcx, %rcx
    jz 8f                        # the empty prefix always matches
    repe cmpsb
    jne 9f
8:  movq $1, %rax
    ret
9:  xorq %rax, %rax
    ret



str_contains:                    # rax = s, rcx = needle  ->  rax = 0 or 1
    movq (%rax), %r8
    movq (%rcx), %r9
    movq %r8, %r10
    subq %r9, %r10               # the last index worth trying
    js 9f
    leaq 8(%rax), %r11
    leaq 8(%rcx), %rdx
    xorq %rax, %rax              # the index, and then the answer
2:  cmpq %r10, %rax
    jg 9f
    movq %r11, %rsi
    addq %rax, %rsi
    movq %rdx, %rdi
    movq %r9, %rcx
    testq %rcx, %rcx
    jz 8f
    repe cmpsb
    je 8f
    incq %rax
    jmp 2b
8:  movq $1, %rax
    ret
9:  xorq %rax, %rax
    ret



str_eq:                          # rax = a, rcx = b  ->  rax = 0 or 1
    movq (%rax), %r8
    cmpq (%rcx), %r8             # different lengths cannot be equal
    jne 9f
    leaq 8(%rax), %rsi
    leaq 8(%rcx), %rdi
    movq %r8, %rcx
    testq %rcx, %rcx
    jz 8f                        # two empty strings are
    repe cmpsb
    jne 9f
8:  movq $1, %rax
    ret
9:  xorq %rax, %rax
    ret



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

vec_new:                         # rax = count  ->  rax = record, slots uninitialised
    leaq 16(,%rax,8), %rcx       # 8 rc + 8 count + 8n, EXACTLY -- see the note above vec_conj
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



# ---- A VECTOR is one of two things, and the word at [p-16] says which.
#
# `conj` copies the whole backing store -- here and in wat's own interpreter alike (F-124) --
# so building a vector by repeated `conj` is O(n^2). wat's answer is `PVec`, the promoting
# vector, and this is that design in machine code: an ARRAY while it is small or bulk-built, a
# 32-way TREE once persistent conj has pushed it past the threshold. Promotion is one-way.
#
#   array:  [arm=0][rc][count][slot]...            p -> count
#   tree:   [arm=1][rc][count][shift][root]        p -> count
#
# **`count` sits at offset 0 in BOTH**, so `length` is the same single `movq (%rax), %rax` for
# either arm, and for a record and a String besides. Only `nth` asks which arm it has, and it
# asks about vectors only -- the compiler knows statically that a record is an array and emits
# the bare indexed load with no test at all.
#
# The arm cannot live in the rc word. That word is a SHARE COUNT that `incq` walks upward, and
# it already carries C-140's `0x100000001`; an arm must survive sharing, so the two would
# collide. A record keeps the old two-word header exactly -- it never conj's, so it is an array
# for ever and pays nothing for any of this.

varr_new:                        # rax = count  ->  rax = array-arm vector, slots uninitialised
    leaq 24(,%rax,8), %rcx       # 8 arm + 8 rc + 8 count + 8n
    movq %r15, %r11
    addq %rcx, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $0, (%r15)              # arm = array
    movq $1, 8(%r15)             # rc = 1
    leaq 16(%r15), %r10
    movq %rax, (%r10)
    movq %r11, %r15
    movq %r10, %rax
    ret



# A tree node is thirty-two slots, and is itself an ordinary `[rc][count][slot]...` object --
# the same shape a record has, so nothing new has to know how to read one.
node_new:                        # -> rax = a node of 32 zeroed slots
    movq %r15, %r11
    addq $272, %r11              # 8 rc + 8 count + 8*32
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $1, (%r15)
    leaq 8(%r15), %r10
    movq $32, (%r10)
    leaq 8(%r10), %rdi
    movq $32, %rcx
    xorq %rax, %rax
    rep stosq                    # an absent child is a zero, which the walk tests for
    movq %r11, %r15
    movq %r10, %rax
    ret



node_copy:                       # rax = node  ->  rax = a fresh copy of it
    push %rbx
    movq %rax, %rbx
    call node_new
    leaq 8(%rax), %rdi
    leaq 8(%rbx), %rsi
    movq $32, %rcx
    rep movsq
    pop %rbx
    ret



# `shift` is 5 per level below the leaves, so the walk is one masked shift a level: at most
# three loads for 32,768 elements, four for a million.
#
# **It clobbers rax and rcx and NOTHING else**, and that is a contract, not an accident.
# C-137 parks expression temporaries in r8-r11 whenever a subtree "emits no call", and `nth` is
# on that whitelist -- which was true until a Vector's `nth` could reach this routine. What the
# pool actually requires is not "no call" but "no scratch register disturbed", so the cheapest
# correct answer is for the routine to disturb none: the three it needs go on the stack. The
# array arm still reaches no call at all.
tree_get:                        # rax = tree, rcx = index  ->  rax = element
    push %rdx
    push %rsi
    push %rdi
    movq %rcx, %rdx              # the index; rcx is about to be a shift count
    movq 8(%rax), %rsi           # shift
    movq 16(%rax), %rdi          # root
1:  testq %rsi, %rsi
    jz 2f
    movq %rdx, %rax
    movq %rsi, %rcx
    shrq %cl, %rax
    andq $31, %rax
    movq 8(%rdi,%rax,8), %rdi    # descend
    subq $5, %rsi
    jmp 1b
2:  movq %rdx, %rax
    andq $31, %rax
    movq 8(%rdi,%rax,8), %rax
    pop %rdi
    pop %rsi
    pop %rdx
    ret



# Persistent append: copy the path from the root to the new leaf and share everything else.
# That is `depth` nodes copied, not `n` slots -- which is the whole point.
tree_push:                       # rax = tree, rcx = element  ->  rax = a new tree
    push %rbx
    push %r12
    push %r13
    movq %rcx, %r12              # the element
    movq (%rax), %r13            # n -- and the index the element lands at
    movq 8(%rax), %rdx           # shift
    movq 16(%rax), %r9           # root
    movq $32, %r10               # full at this shift? then the tree gains a level
    movq %rdx, %rcx
    shlq %cl, %r10
    cmpq %r13, %r10
    jne 1f
    call node_new
    movq %r9, 8(%rax)            # the old root becomes child zero of the new one
    movq %rax, %r9
    addq $5, %rdx
1:  pushq %rdx                   # the shift the header will carry
    movq %r9, %rax
    call node_copy
    movq %rax, %r8               # the new root
    movq %rax, %rbx              # and the cursor walking down it
2:  testq %rdx, %rdx
    jz 3f
    movq %r13, %rax
    movq %rdx, %rcx
    shrq %cl, %rax
    andq $31, %rax
    movq %rax, %r9               # which slot at this level -- **r9, not r10**: `node_new` uses
    movq 8(%rbx,%r9,8), %rax     # r10 for the object it is building, so an index parked there
    testq %rax, %rax             # comes back as a pointer and the child is linked into orbit
    jz 4f
    call node_copy               # a child there: copy it
    jmp 5f
4:  call node_new                # none yet: a fresh one
5:  movq %rax, 8(%rbx,%r9,8)
    movq %rax, %rbx
    subq $5, %rdx
    jmp 2b
3:  movq %r13, %rax
    andq $31, %rax
    movq %r12, 8(%rbx,%rax,8)    # the element, in the leaf
    popq %rdx
    movq %r15, %r11              # the header: [arm=1][rc=1][count][shift][root]
    addq $40, %r11
    cmpq 8(%r14), %r11
    jbe 6f
    call oom
6:  movq $1, (%r15)
    movq $1, 8(%r15)
    leaq 16(%r15), %rax
    leaq 1(%r13), %rcx
    movq %rcx, (%rax)
    movq %rdx, 8(%rax)
    movq %r8, 16(%rax)
    movq %r11, %r15
    pop %r13
    pop %r12
    pop %rbx
    ret



# The one-way promotion. It happens once per vector, at the threshold, so the cost of walking
# the array into the tree is paid against every append that follows it.
tree_from_arr:                   # rax = array-arm vector  ->  rax = the same elements, as a tree
    push %rbx
    push %r12
    push %r13
    movq %rax, %rbx              # the source
    movq (%rbx), %r13            # n
    xorq %r12, %r12
    call node_new
    movq %rax, %r9
    movq %r15, %r11
    addq $40, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $1, (%r15)              # an empty tree: count 0, shift 0, one leaf
    movq $1, 8(%r15)
    leaq 16(%r15), %rax
    movq $0, (%rax)
    movq $0, 8(%rax)
    movq %r9, 16(%rax)
    movq %r11, %r15
2:  cmpq %r13, %r12
    jae 3f
    movq 8(%rbx,%r12,8), %rcx
    call tree_push
    incq %r12
    jmp 2b
3:  pop %r13
    pop %r12
    pop %rbx
    ret



# `vec_conj` is the SHARED path -- the compiler could not prove the container dead, so the value
# must survive. That is the path F-124 measured as quadratic, and the one that promotes.
vec_conj:                        # rax = vector, rcx = element  ->  rax = a longer vector
    cmpq $0, -16(%rax)
    jne tree_push                # already a tree: a path copy, O(log n)
    movq (%rax), %r8
    cmpq $8, %r8                 # PROMOTION_THRESHOLD, as wat's own PVec uses
    jb 1f
    pushq %rcx
    call tree_from_arr
    popq %rcx
    jmp tree_push
1:  movq %rcx, %r10              # still small: copying it is cheaper than a tree
    leaq 32(,%r8,8), %rdx        # 8 arm + 8 rc + 8 count + 8(n+1)
    movq %r15, %r11
    addq %rdx, %r11
    cmpq 8(%r14), %r11
    jbe 2f
    call oom
2:  movq $0, (%r15)              # arm = array
    movq $1, 8(%r15)             # rc = 1
    leaq 16(%r15), %r9
    leaq 1(%r8), %rdx
    movq %rdx, (%r9)             # the new count
    leaq 8(%r9), %rdi
    leaq 8(%rax), %rsi
    movq %r8, %rcx
    rep movsq
    movq %r10, (%rdi)            # and the new element on the end
    movq %r11, %r15
    movq %r9, %rax
    ret



# `vec_conj_own` is `conj` where the COMPILER has proved the container is a last use -- no later
# read of that variable can observe a change. That plus a reference count of 1 is enough to
# extend in place, which is what turns an accumulator loop from O(n^2) into O(n). It is Rust's
# `Vec::push` and Clojure's transient, arrived at from two halves neither has alone: the count
# rules out aliases, last-use rules out later reads. A tree is handed straight to the persistent
# path -- that is already O(log n), so there is nothing to win by mutating it.
vec_conj_own:                    # rax = vector (proved dead after this), rcx = element
    cmpq $0, -16(%rax)
    {disp32} jne vec_conj        # 32-bit, so it still reaches when the layout changes
    movabsq $0x100000001, %r9    # the marker: unique, and already in a power-of-two block
    cmpq %r9, -8(%rax)
    je 2f
    cmpq $1, -8(%rax)            # unique, in a block of exactly its own size?
    {disp32} jne vec_conj        # 0 is a literal, >1 was stored somewhere durable
    movq (%rax), %r8
    leaq 8(%rax,%r8,8), %rdx     # one past the last slot
    cmpq %r15, %rdx              # still the top of the heap?
    je 1f                        # then extending it costs one bump and no slack at all
    movq %rcx, %r9               # displaced by something else: promote it to a block with room
    jmp 9f
1:  movq %r15, %r11
    addq $8, %r11
    cmpq 8(%r14), %r11
    jbe 4f
    call oom
4:  movq %rcx, (%r15)            # the new element goes exactly where r15 points
    movq %r11, %r15
    leaq 1(%r8), %rdx
    movq %rdx, (%rax)
    ret
2:  movq (%rax), %r8             # marked: the slack is derivable from the count alone
    movq %rcx, %r9               # park the element: rcx is about to be a shift count
    leaq 23(,%r8,8), %rdx
    bsrq %rdx, %rcx
    movq $2, %rdx
    shlq %cl, %rdx               # the block it was given
    leaq 32(,%r8,8), %r11        # what one more slot would need
    cmpq %rdx, %r11
    ja 9f
    movq %r9, 8(%rax,%r8,8)      # it fits: write the slot and bump the count
    leaq 1(%r8), %rdx
    movq %rdx, (%rax)
    ret
9:  movq (%rax), %r8             # grow: copy into a power-of-two block, and mark it
    leaq 31(,%r8,8), %rdx        # (8 arm + 8 rc + 8 count + 8(n+1)) - 1
    bsrq %rdx, %rcx
    movq $2, %rdx
    shlq %cl, %rdx
    movq %r15, %r11
    addq %rdx, %r11
    cmpq 8(%r14), %r11
    jbe 3f
    call oom
3:  movq $0, (%r15)              # arm = array
    movabsq $0x100000001, %rdx
    movq %rdx, 8(%r15)
    leaq 16(%r15), %r10
    leaq 1(%r8), %rdx
    movq %rdx, (%r10)            # the new count
    leaq 8(%r10), %rdi
    leaq 8(%rax), %rsi
    movq %r8, %rcx
    rep movsq
    movq %r9, (%rdi)             # and the new element on the end
    movq %r11, %r15
    movq %r10, %rax
    ret



slot_set:                        # rax = vector/record, rcx = index, rdx = value -> rax = a copy
    push %rbx                    # rbx, r12 and r13 hold the caller's parameters now
    movq (%rax), %r8             # with that one slot replaced; this is `assoc`
    movq %rcx, %r10              # the index, before rcx is the copy count
    movq %rdx, %rbx              # and the value
    movq %r15, %r11
    leaq 16(,%r8,8), %rdx        # the same count, so an EXACT block: assoc never grows
    addq %rdx, %r11
    cmpq 8(%r14), %r11
    jbe 1f
    call oom
1:  movq $1, (%r15)              # rc = 1
    leaq 8(%r15), %r9
    movq %r8, (%r9)
    leaq 8(%r9), %rdi
    leaq 8(%rax), %rsi
    movq %r8, %rcx
    rep movsq
    movq %r11, %r15
    movq %r9, %rax
    movq %rbx, 8(%rax,%r10,8)
    pop %rbx
    ret



# ---- the last mile: a file, as bytes.
#
# A compiled program can open and write a file in three syscalls. What it cannot do is call
# wat's `:wat::io::` verbs, because those are Rust inside the evaluator -- and it cannot route
# around them through a String, because a String is UTF-8 there and a byte array here, so the two
# disagree on the first byte above 0x7f, which an ELF header has in its second byte. So these two
# are the F-119 contract made concrete: `wat.prim/read-hex` and `wat.prim/write-hex` have a wat
# definition for the interpreter (elf/lib/prim.wat) and this implementation for the compiler, and
# the program that uses them still runs both ways.
#
# Hex is the carrier for the same reason the rest of elf/ uses it: it is the only byte
# representation wat can hold in a String (F-118).
#
# **These three park their buffers in r12, not r11.** `syscall` destroys rcx and r11 -- the
# instruction uses them to save rip and rflags -- so a pointer left in r11 across an `open` comes
# back as garbage and `write` answers -14, EFAULT. Which it did.

hexval:                          # rax = one ascii hex digit  ->  rax = 0..15
    subq $48, %rax
    cmpq $9, %rax
    jbe 1f
    subq $39, %rax               # 'a' lands on 10
1:  ret



hexchar:                         # rax = 0..15  ->  al = one ascii hex digit
    cmpq $10, %rax
    jb 1f
    addq $39, %rax
1:  addq $48, %rax
    ret



prim_write_hex:                  # rax = path, rcx = hex  ->  rax = bytes written
    push %rbx
    push %r12
    movq %rax, %r8
    movq %rcx, %r9
    movq %r15, %r10              # a NUL-terminated path, at the heap top as scratch
    leaq 8(%r8), %rsi
    movq %r10, %rdi
    movq (%r8), %rcx
    rep movsb
    movb $0, (%rdi)
    incq %rdi
    movq %rdi, %r12              # and the decoded bytes after it
    movq (%r9), %rdx
    shrq $1, %rdx
    movq %rdx, %rbx              # how many there will be
    leaq 8(%r9), %rsi
    testq %rdx, %rdx
    jz 3f
2:  movzbq (%rsi), %rax
    call hexval
    shlq $4, %rax
    movq %rax, %rcx
    movzbq 1(%rsi), %rax
    call hexval
    orq %rcx, %rax
    movb %al, (%rdi)
    addq $2, %rsi
    incq %rdi
    decq %rdx
    jnz 2b
3:  movq $2, %rax                # open(path, O_WRONLY|O_CREAT|O_TRUNC, 0755)
    movq %r10, %rdi
    movq $577, %rsi
    movq $493, %rdx
    syscall
    movq %rax, %r9
    movq $1, %rax                # write(fd, bytes, n)
    movq %r9, %rdi
    movq %r12, %rsi
    movq %rbx, %rdx
    syscall
    movq %rax, %r10
    movq $3, %rax                # close(fd)
    movq %r9, %rdi
    syscall
    movq %r10, %rax
    pop %r12
    pop %rbx
    ret



prim_read_hex:                   # rax = path  ->  rax = a String of hex
    push %r12
    movq %r15, %r10
    leaq 8(%rax), %rsi
    movq %r10, %rdi
    movq (%rax), %rcx
    rep movsb
    movb $0, (%rdi)
    incq %rdi
    movq %rdi, %r12              # the file lands after the path
    movq $2, %rax                # open(path, O_RDONLY)
    movq %r10, %rdi
    xorq %rsi, %rsi
    xorq %rdx, %rdx
    syscall
    movq %rax, %r8
    movq %r12, %r9
1:  movq $0, %rax                # read(fd, cursor, 65536) until it stops giving
    movq %r8, %rdi
    movq %r9, %rsi
    movq $65536, %rdx
    syscall
    testq %rax, %rax
    jle 2f
    addq %rax, %r9
    jmp 1b
2:  movq $3, %rax                # close(fd)
    movq %r8, %rdi
    syscall
    movq %r9, %rdx
    subq %r12, %rdx              # how many bytes that was
    leaq 7(%r9), %r8             # the String goes ABOVE the scratch, aligned
    andq $-8, %r8
    movq %rdx, %rax
    addq %rax, %rax              # two hex digits a byte
    leaq 15(%rax), %rcx
    bsrq %rcx, %rcx
    movq $2, %rsi
    shlq %cl, %rsi               # rounded up to a power of two, like every other String
    addq %r8, %rsi
    cmpq 8(%r14), %rsi
    jbe 3f
    call oom
3:  movq %rsi, %r15
    movq $1, (%r8)
    leaq 8(%r8), %r10
    movq %rax, (%r10)
    leaq 8(%r10), %rdi
    movq %r12, %rsi
    testq %rdx, %rdx
    jz 5f
4:  movzbq (%rsi), %rax
    movq %rax, %rcx
    shrq $4, %rax
    call hexchar
    movb %al, (%rdi)
    incq %rdi
    movq %rcx, %rax
    andq $15, %rax
    call hexchar
    movb %al, (%rdi)
    incq %rdi
    incq %rsi
    decq %rdx
    jnz 4b
5:  movq %r10, %rax
    pop %r12
    ret



io_read_file:                    # rax = path  ->  rax = a String of the file's bytes
    push %r12
    movq %r15, %r10
    leaq 8(%rax), %rsi
    movq %r10, %rdi
    movq (%rax), %rcx
    rep movsb
    movb $0, (%rdi)
    incq %rdi
    movq %rdi, %r12
    movq $2, %rax                # open(path, O_RDONLY)
    movq %r10, %rdi
    xorq %rsi, %rsi
    xorq %rdx, %rdx
    syscall
    movq %rax, %r8
    movq %r12, %r9
1:  movq $0, %rax                # read until it stops giving
    movq %r8, %rdi
    movq %r9, %rsi
    movq $65536, %rdx
    syscall
    testq %rax, %rax
    jle 2f
    addq %rax, %r9
    jmp 1b
2:  movq $3, %rax                # close(fd)
    movq %r8, %rdi
    syscall
    movq %r9, %rdx
    subq %r12, %rdx
    leaq 7(%r9), %r8             # the String goes above the scratch, aligned
    andq $-8, %r8
    leaq 15(%rdx), %rcx
    bsrq %rcx, %rcx
    movq $2, %rsi
    shlq %cl, %rsi               # rounded up to a power of two, like every other String
    addq %r8, %rsi
    cmpq 8(%r14), %rsi
    jbe 3f
    call oom
3:  movq %rsi, %r15
    movq $1, (%r8)
    leaq 8(%r8), %r10
    movq %rdx, (%r10)
    leaq 8(%r10), %rdi
    movq %r12, %rsi
    movq %rdx, %rcx
    rep movsb
    movq %r10, %rax
    pop %r12
    ret
