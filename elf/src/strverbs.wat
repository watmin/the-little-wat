;; The string verbs a reader is made of. `subs` alone was sixteen of the 117 occurrences
;; elf/census.wat counts between this compiler and compiling itself, and a lexer is `subs`,
;; `starts-with?` and a comparison in a loop.
;;
;; Run both ways; they must agree.

(wat.core/defn user/digits? [s :- wat.type/String i :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((wat.core/>= i (wat.string/length s)) true)
    ((wat.core/not (wat.string/contains? "0123456789"
                     (wat.string/subs s i (wat.core/+ i 1)))) false)
    (:else (user/digits? s (wat.core/+ i 1)))))

;; a token scanner: everything up to the first space
(wat.core/defn user/upto [s :- wat.type/String i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i (wat.string/length s)) i)
    ((wat.string/starts-with? (wat.string/subs s i (wat.string/length s)) " ") i)
    (:else (user/upto s (wat.core/+ i 1)))))

;; reverse a string one character at a time -- subs in a loop, and the accumulator is linear
(wat.core/defn user/rev [s :- wat.type/String i :- wat.type/i64 acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/< i 0) acc
    (user/rev s (wat.core/- i 1)
      (wat.string/concat acc (wat.string/subs s i (wat.core/+ i 1))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s "compile thyself"]
    (wat.kernel/println (wat.string/subs s 0 7))
    (wat.kernel/println (wat.string/subs s 8 (wat.string/length s)))
    (wat.kernel/println (wat.string/subs s 7 7))
    (wat.kernel/println (user/upto s 0))
    (wat.kernel/println (wat.string/starts-with? s "comp"))
    (wat.kernel/println (wat.string/starts-with? s "thy"))
    (wat.kernel/println (wat.string/starts-with? s ""))
    (wat.kernel/println (wat.string/contains? s "thy"))
    (wat.kernel/println (wat.string/contains? s "xyz"))
    (wat.kernel/println (wat.string/contains? s ""))
    (wat.kernel/println (user/rev s (wat.core/- (wat.string/length s) 1) ""))
    (wat.kernel/println (user/digits? "40312" 0))
    (wat.kernel/println (user/digits? "4a312" 0)))

  ;; and integers back to text, which is how a compiler reports anything
  (wat.kernel/println (wat.i64/to-string 0))
  (wat.kernel/println (wat.i64/to-string -90210))
  (wat.kernel/println (wat.i64/to-string 9223372036854775807))
  (wat.kernel/println (wat.string/length (wat.i64/to-string -1234567890)))
  (wat.kernel/println (wat.string/concat "n=" (wat.i64/to-string 42))))
