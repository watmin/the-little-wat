;; elf/lib/prim.wat -- the two verbs that reach the disk, for the INTERPRETER.
;;
;; `elf/compile.wat` implements these two natively: `prim/write-hex` compiles to
;; open/write/close and `prim/read-hex` to open/read/close, with the hex decoded and encoded
;; by hand. So the definitions here are the ones the interpreter uses, and the compiler's are the
;; ones a compiled program uses, and a program calling them runs **both ways**.
;;
;; That is the whole of what F-119 asks for, in two verbs: a primitive with a stated meaning and
;; two implementations, rather than a Rust function only one evaluator can reach.
;;
;; **Why hex rather than bytes.** A wat String is UTF-8 and a compiled String is a byte array, so
;; the two disagree on the first byte above 0x7f -- which an ELF header has in its second byte.
;; Hex is the only byte representation both can hold (F-118), which is why the rest of elf/ is
;; built on it too.

(:wat::core::defn :prim::write-hex [path <- :wat::core::String hex <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::core::Bytes::from-hex hex)
    [:wat::core::Option.None {}
      (:wat::kernel::assertion-failed! :message "assembled hex did not decode")]
    [:wat::core::Option.Some {:value bs}
      (:wat::core::let [w (:wat::io::IOWriter/open-file path)]
        (:wat::core::do
          (:wat::io::IOWriter/write-all w bs)
          (:wat::io::IOWriter/flush w)
          (:wat::io::IOWriter/close w)
          (:wat::core::length bs)))]))

(:wat::core::defn :prim::read-hex [path <- :wat::core::String] -> :wat::core::String
  (:wat::core::Bytes::to-hex (:wat::io::IOReader/read-all (:wat::io::IOReader/open-file path))))
