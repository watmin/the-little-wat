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
    jne str_cat
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
    jmp str_cat

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

# ---- Vectors come in two block shapes, and the count word below the pointer says which.
#
# A String's block is always the next power of two at or above its header plus its bytes, so
# its spare room needs no header field. Doing the same for every vector made the compiler's own
# peak WORSE by 349 MB: `vec_new` and `slot_set` allocate blocks of a known, final size -- every
# record, and every `assoc` on one -- and rounding those up wastes as much as half of each of
# the millions the compiler builds, for slack that is never used, because a record never grows.
#
# So slack is given out only where it is earned, and the rule is ADAPTIVE. An accumulator that
# is still the top of the heap is extended by one bump, exactly as before and with no waste at
# all. Only when it has been DISPLACED -- something else allocated since, which is the case that
# used to fall back to a full copy every time and made the whole thing quadratic -- is it
# promoted into a power-of-two block, and marked `0x100000001` in the count word below the
# pointer. The reachable values are 0 (a literal), 1 (unique, exact block), and 2, 3, ... from
# the increment-only share rule, so the marker cannot collide, and `incq` on a marked vector
# lands on neither 1 nor the marker -- shared, which is what it has then become.
#
# `vec_conj_own` is `conj` where the COMPILER has proved the container is a last use -- no later
# read of that variable can observe a change. That plus a reference count of 1 (never stored
# anywhere durable) plus being the top of the heap is enough to extend in place, which is what
# turns an accumulator loop from O(n^2) into O(n). It is Rust's `Vec::push` and Clojure's
# transient, arrived at from the two halves neither implementation has alone: the count rules out
# aliases, last-use rules out later reads.
vec_conj_own:                    # rax = vector (proved dead after this), rcx = element
    movabsq $0x100000001, %r9    # the marker: unique, and already in a power-of-two block
    cmpq %r9, -8(%rax)
    je 2f
    cmpq $1, -8(%rax)            # unique, in a block of exactly its own size?
    jne vec_conj                 # 0 is a literal, >1 was stored somewhere durable
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
    leaq 15(,%r8,8), %rdx
    bsrq %rdx, %rcx
    movq $2, %rdx
    shlq %cl, %rdx               # the block it was given
    leaq 24(,%r8,8), %r11        # what one more slot would need
    cmpq %rdx, %r11
    ja 9f
    movq %r9, 8(%rax,%r8,8)      # it fits: write the slot and bump the count
    leaq 1(%r8), %rdx
    movq %rdx, (%rax)
    ret
9:  movq (%rax), %r8             # grow: copy into a power-of-two block, and mark it
    leaq 23(,%r8,8), %rdx        # (8 count + 8 mark + 8(n+1)) - 1
    bsrq %rdx, %rcx
    movq $2, %rdx
    shlq %cl, %rdx
    movq %r15, %r11
    addq %rdx, %r11
    cmpq 8(%r14), %r11
    jbe 3f
    call oom
3:  movabsq $0x100000001, %rdx
    movq %rdx, (%r15)
    leaq 8(%r15), %r10
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

vec_conj:                        # rax = vector, rcx = element  ->  rax = a longer copy
    movq %rcx, %r10              # the element, before rcx becomes a shift count
    movq (%rax), %r8
    leaq 24(,%r8,8), %rdx        # 8 rc + 8 count + 8(n+1), exactly
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
