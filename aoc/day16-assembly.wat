;; Advent of Code's assembly shape, in wat: a four-register machine, read from text.
;;
;; Four instructions. `cpy x y` copies a register or a literal into a register; `inc r` and
;; `dec r` change one by one; `jnz x y` jumps y instructions when x is not zero.
;;
;; Part one: the value left in register a.
;; Part two: the same, with register c starting at 1 instead.
;;
;; **This is the same machine `lox/` spends seventeen chapters on, in forty lines, and the
;; comparison is the point of having it here.** The lox VM's instructions are a `defenum` with
;; typed operands, decided at compile time; this one's are three strings decided at run time, and
;; an operand is "a register name or a number" with nothing to say which until it is read. So:
;;
;;   * the dispatch is a `cond` over strings rather than an exhaustive `match`, and a typo in the
;;     input is a runtime error where a bad opcode in lox is unconstructible (C-098);
;;   * the registers are a four-element record rather than a stack, so `cpy 5 b` is
;;     `:wat::core::assoc` on a `defrecord` -- F-113, and the reason this file is short;
;;   * and the jump is `ip + y` with y read from the text, so the ip is an ordinary loop argument
;;     exactly as C-098 recommends -- no frame record per instruction.
;;
;; The puzzle and its input are ours (aoc/input/day16-assembly.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day16-assembly.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day16-assembly.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defrecord :aoc::Regs [a <- :wat::core::i64  b <- :wat::core::i64
                                   c <- :wat::core::i64  d <- :wat::core::i64])

(:wat::core::typealias :aoc::Prog (:wat::core::Vector :- [:aoc::Lines]))

(:wat::core::defn :aoc::reg? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= s "a")
    (:wat::core::or (:wat::core::= s "b")
      (:wat::core::or (:wat::core::= s "c") (:wat::core::= s "d")))))

(:wat::core::defn :aoc::get-reg [r <- :aoc::Regs s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= s "a") (:aoc::Regs/a r))
    ((:wat::core::= s "b") (:aoc::Regs/b r))
    ((:wat::core::= s "c") (:aoc::Regs/c r))
    (:else (:aoc::Regs/d r))))

;; F-113: one field changes, so one field is written. Restating the other three would be the
;; obvious spelling and about three times the cost on a four-field record.
(:wat::core::defn :aoc::set-reg [r <- :aoc::Regs s <- :wat::core::String v <- :wat::core::i64] -> :aoc::Regs
  (:wat::core::cond
    ((:wat::core::= s "a") (:wat::core::assoc r :a v))
    ((:wat::core::= s "b") (:wat::core::assoc r :b v))
    ((:wat::core::= s "c") (:wat::core::assoc r :c v))
    (:else (:wat::core::assoc r :d v))))

;; an operand is a register or a literal, and only the text says which
(:wat::core::defn :aoc::value [r <- :aoc::Regs s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::if (:aoc::reg? s) (:aoc::get-reg r s) (:aoc::to-int s)))

(:wat::core::defn :aoc::step [p <- :aoc::Prog ip <- :wat::core::i64 r <- :aoc::Regs] -> :aoc::Regs
  (:wat::core::if (:wat::core::or (:wat::core::< ip 0) (:wat::core::>= ip (:wat::core::length p)))
    r
    (:wat::core::let [ins (:wat::core::nth p ip)
                      op (:wat::core::nth ins 0)
                      x (:wat::core::nth ins 1)]
      (:wat::core::cond
        ((:wat::core::= op "cpy")
          (:aoc::step p (:wat::core::+ ip 1)
            (:aoc::set-reg r (:wat::core::nth ins 2) (:aoc::value r x))))
        ((:wat::core::= op "inc")
          (:aoc::step p (:wat::core::+ ip 1) (:aoc::set-reg r x (:wat::core::+ (:aoc::get-reg r x) 1))))
        ((:wat::core::= op "dec")
          (:aoc::step p (:wat::core::+ ip 1) (:aoc::set-reg r x (:wat::core::- (:aoc::get-reg r x) 1))))
        ((:wat::core::= op "jnz")
          (:aoc::step p
            (:wat::core::if (:wat::core::= (:aoc::value r x) 0) (:wat::core::+ ip 1)
              (:wat::core::+ ip (:aoc::value r (:wat::core::nth ins 2))))
            r))
        (:else (:wat::kernel::assertion-failed! :message (:wat::string::concat "unknown opcode: " op)))))))

(:wat::core::defn :aoc::parse [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Prog] -> :aoc::Prog
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::parse ls (:wat::core::+ i 1)
      (:wat::core::conj acc (:aoc::non-empty (:wat::string::split (:wat::core::nth ls i) " "))))))

(:wat::core::defn :aoc::run [p <- :aoc::Prog c0 <- :wat::core::i64] -> :wat::core::i64
  (:aoc::Regs/a (:aoc::step p 0 (:aoc::Regs :a 0 :b 0 :c c0 :d 0))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [p (:aoc::parse (:aoc::lines "aoc/input/day16-assembly.txt") 0 (:wat::core::Vector :- [:aoc::Lines]))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day16-assembly.expected"
                         "aoc day16 assembly"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::run p 0))
                           (int (:aoc::run p 1))))))
