;; Crafting Interpreters chapter 19 (strings), in wat.
;;
;; In C this is the chapter where Lox grows a HEAP. A value can now be a pointer to an `Obj`,
;; every `Obj` carries a type tag, `ObjString` adds a length and a character array, and the VM
;; keeps a linked list of every object it has ever allocated so `freeObjects()` can walk it at
;; shutdown. Concatenation allocates, copies both halves, and takes ownership of the result.
;;
;; **Almost none of that is portable, and saying which part is the point of this file.** wat owns
;; the heap, so `Obj`, `ObjString`, `allocateObject`, `vm.objects` and `freeObjects` have no
;; wat-level meaning: a value can be a string, and that is the whole of it -- one variant, one
;; `:wat::string::concat`. What survives the C is the LANGUAGE half, and that half is checked
;; here in full: what `+` does with mixed operands, whether a string is truthy, whether two
;; separately-built strings are equal, and what the comparison operators refuse.
;;
;; The equality question is the one worth stopping on. In C, `"a" == "a"` at this point in the
;; book is a length check and a `memcmp`, and chapter 20 replaces it with pointer equality by
;; interning every string. In wat `=` on a String is already structural, so the correctness the
;; interning buys is present before the chapter that adds it -- what remains is its COST, which
;; lox/ch20-hash-tables.wat measures.
;;
;; Run: wat lox/ch19-strings.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c19::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c19::run [src <- :wat::core::String] -> :wat::core::String (:loxv::interpret src))

(:wat::core::defn :c19::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile src))))

(:wat::core::defn :c19::consts [src <- :wat::core::String] -> :wat::core::String
  (:wat::i64::to-string (:wat::core::length (:loxv::Chunk/constants (:loxv::C/chunk (:loxv::compile src))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [book "\"st\" + \"ri\" + \"ng\""]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "== " book " =="))
      (:wat::kernel::println (:wat::string::concat "  code   " (:c19::code book)))
      (:wat::kernel::println (:wat::string::concat "  value  " (:c19::run book)))
      (:wat::kernel::println "")
      (:wat::kernel::println "---- what strings must satisfy ----")
      (:wat::core::let
        [rs
         [(:c19::expect "the chapter's own example  " (:c19::run book) "string")

          ;; LITERALS: the scanner keeps the quotes, the compiler drops them
          (:c19::expect "a literal prints unquoted  " (:c19::run "\"one\"") "one")
          (:c19::expect "the empty string           " (:c19::run "\"\"") "")
          (:c19::expect "a string is a constant     " (:c19::code "\"a\"") "CONST/0 RET")
          (:c19::expect "punctuation survives       " (:c19::run "\"a != b // c\"") "a != b // c")
          (:c19::expect "so do spaces               " (:c19::run "\"  x  \"") "  x  ")

          ;; CONCATENATION
          (:c19::expect "\"a\"+\"b\"                    " (:c19::run "\"a\" + \"b\"") "ab")
          (:c19::expect "left-associative           " (:c19::run "\"a\" + \"b\" + \"c\"") "abc")
          (:c19::expect "with the empty string      " (:c19::run "\"\" + \"x\"") "x")
          (:c19::expect "and numbers still add      " (:c19::run "1 + 2") "3")

          ;; `+` IS THE OVERLOADED ONE, and its message changed in this chapter
          (:c19::expect "\"a\" + 1 is refused         " (:c19::run "\"a\" + 1")
            "[line 1] Runtime error: Operands must be two numbers or two strings.")
          (:c19::expect "1 + \"a\" too                " (:c19::run "1 + \"a\"")
            "[line 1] Runtime error: Operands must be two numbers or two strings.")
          (:c19::expect "\"a\" + nil too              " (:c19::run "\"a\" + nil")
            "[line 1] Runtime error: Operands must be two numbers or two strings.")
          ;; every OTHER arithmetic operator keeps the shorter message
          (:c19::expect "\"a\" - \"b\" is numbers-only  " (:c19::run "\"a\" - \"b\"")
            "[line 1] Runtime error: Operands must be numbers.")
          (:c19::expect "\"a\" * 2 as well            " (:c19::run "\"a\" * 2")
            "[line 1] Runtime error: Operands must be numbers.")
          (:c19::expect "-\"a\" is the unary message  " (:c19::run "-\"a\"")
            "[line 1] Runtime error: Operand must be a number.")
          ;; Lox does not order strings -- `<` is numbers only, deliberately
          (:c19::expect "\"a\" < \"b\" is refused       " (:c19::run "\"a\" < \"b\"")
            "[line 1] Runtime error: Operands must be numbers.")

          ;; EQUALITY: the thing chapter 20's interning is for. Structural here already.
          (:c19::expect "\"a\" == \"a\"                 " (:c19::run "\"a\" == \"a\"") "true")
          (:c19::expect "\"a\" == \"b\"                 " (:c19::run "\"a\" == \"b\"") "false")
          (:c19::expect "\"\" == \"\"                   " (:c19::run "\"\" == \"\"") "true")
          ;; built by different routes, still equal -- in C at this point this is a memcmp, and
          ;; in chapter 20 it becomes a pointer comparison because the two are the same object
          (:c19::expect "\"ab\" == \"a\"+\"b\"            " (:c19::run "\"ab\" == \"a\" + \"b\"") "true")
          (:c19::expect "\"ab\" != \"ba\"               " (:c19::run "\"ab\" != \"ba\"") "true")
          ;; across types, still false
          (:c19::expect "\"1\" == 1 is FALSE          " (:c19::run "\"1\" == 1") "false")
          (:c19::expect "\"\" == nil is FALSE         " (:c19::run "\"\" == nil") "false")
          (:c19::expect "\"\" == false is FALSE       " (:c19::run "\"\" == false") "false")

          ;; TRUTHINESS: a string is truthy, including the empty one
          (:c19::expect "!\"\" is false               " (:c19::run "!\"\"") "false")
          (:c19::expect "!\"a\" is false              " (:c19::run "!\"a\"") "false")
          (:c19::expect "!!\"\" is true               " (:c19::run "!!\"\"") "true")

          ;; NO INTERNING YET: two identical literals are two constants. Chapter 20 is where
          ;; that stops being true, and lox/ch20-hash-tables.wat measures what it saves.
          (:c19::expect "two \"a\" literals, 2 consts " (:c19::consts "\"a\" == \"a\"") "2")
          (:c19::expect "one literal, 1 const       " (:c19::consts "\"a\"") "1")

          ;; an unterminated string is still the scanner's error, and reaches the compiler
          (:c19::expect "an unterminated string     " (:c19::run "\"oops")
            "[line 1] Error: Unterminated string.")]]
        (:wat::core::do
          (:wat::kernel::println "")
          (:wat::kernel::println "---- what this chapter cost in wat ----")
          (:wat::kernel::println "One enum variant and one call to string::concat. The rest of the")
          (:wat::kernel::println "chapter -- Obj, ObjString, allocateObject, the vm.objects list that")
          (:wat::kernel::println "freeObjects walks, and taking ownership of a concatenation's result --")
          (:wat::kernel::println "is C's memory management, and wat owns the heap.")
          (:wat::kernel::println "")
          (:wat::kernel::println "That is not nothing lost: the object list is what chapter 26's")
          (:wat::kernel::println "mark-sweep collector walks, so the GC chapter will have to build its")
          (:wat::kernel::println "own heap to collect, the way SICP 5.3 did (C-081). And `==` on two")
          (:wat::kernel::println "strings is already structural here, so the CORRECTNESS chapter 20's")
          (:wat::kernel::println "interning buys arrives before the chapter that adds it -- what is left")
          (:wat::kernel::println "of interning is its cost, which is a measurement, not a port.")
          (:wat::kernel::println "")
          (:wat::test::assert-eq
            (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                 (:wat::core::+ a b)) 0 rs)
            0))))))
