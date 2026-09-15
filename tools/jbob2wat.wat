;; tools/jbob2wat.wat: translates J-Bob's Scheme (vendor/j-bob/*.scm, BSD 2-Clause, Friedman
;; and Eastlund) into wat, and generates The Little Prover's chapter programs from the guile
;; oracle's answers (oracle/prover.expected.tsv). Our own code.
;;
;; Built the way wat/fix.wat's codemods are: read the source with read-string, rebuild each
;; form with the AST tools (ast->children, with-children, symbol-node, keyword-node), render it
;; with ast->source, and write-file the result.
;;
;; J-Bob's language is tiny: top-level (defun name (formals) body), and in bodies only
;; variables, (quote datum), (if Q A E) and applications.
;; - A defun with formals becomes
;;     (:wat::core::defn :jb::NAME [x <- :wat::WatAST ...] -> :wat::WatAST BODY)
;;   in the keyword spelling, so every call in the generated code is type-checked at startup
;;   (F-014 is about the symbol spelling).
;; - A defun with NO formals is a constant: it becomes (:wat::core::def :jb::NAME BODY),
;;   computed once when loaded, and a call (name) becomes the value :jb::NAME. The book's
;;   transcript builds each chapter's definitions from the previous chapter's, so without this
;;   every entry would re-run every proof before it.
;; - `if` tests J-Bob's truth: (:jb::true? Q).
;; - Quoted data is kept as data, with any (:wat::core::quote x) inside it turned back into
;;   (quote x). wat's reader turns a nested 'x into the keyword form, and J-Bob looks for the
;;   symbol `quote`.
;; - Names are mangled for wat: / -> --, . -> _, < -> -lt-, = -> -eq-, + -> -plus-. The
;;   primitives + and < are :jb::plus and :jb::lt (books/little-prover/lib/j-bob-lang.wat).
;;
;; Outputs:
;;   books/little-prover/lib/j-bob.wat              J-Bob itself
;;   books/little-prover/lib/transcript-chNN.wat    the transcript, split on its ";; Chapter N" lines
;;   books/little-prover/chNN-transcript.wat        one program per chapter, checking every entry
;;                                                  against guile's answer
;;
;; Run from the repository root:  wat tools/jbob2wat.wat

(:wat::core::typealias :jb2w::Names (:wat::core::HashSet :- [:wat::core::String]))
(:wat::core::typealias :jb2w::Forms (:wat::core::Vector :- [:wat::WatAST]))

;; ---- strings and names

(:wat::core::defn :jb2w::replace [s <- :wat::core::String from <- :wat::core::String to <- :wat::core::String] -> :wat::core::String
  (:wat::string::join to (:wat::string::split s from)))

(:wat::core::defn :jb2w::mangle [s <- :wat::core::String] -> :wat::core::String
  (:jb2w::replace (:jb2w::replace (:jb2w::replace (:jb2w::replace (:jb2w::replace s "/" "--") "." "_") "<" "-lt-") "=" "-eq-") "+" "-plus-"))

(:wat::core::defn :jb2w::fn-name [s <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= s "+") ":jb::plus")
    ((:wat::core::= s "<") ":jb::lt")
    (:else (:wat::string::concat ":jb::" (:jb2w::mangle s)))))

(:wat::core::defn :jb2w::pad2 [s <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= (:wat::string::length s) 1) (:wat::string::concat "0" s) s))

;; ---- AST helpers

(:wat::core::defn :jb2w::symbol-named? [n <- :wat::WatAST name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind n) "symbol")
    (:wat::core::= (:wat::core::ast-name n) name)
    false))

;; Either spelling of quote: the symbol `quote`, or the keyword a nested 'x reads as.
(:wat::core::defn :jb2w::quote-head? [n <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:jb2w::symbol-named? n "quote")
    true
    (:wat::core::if (:wat::core::= (:wat::core::ast-kind n) "keyword")
      (:wat::core::= (:wat::core::ast->source n) ":wat::core::quote")
      false)))

(:wat::core::defn :jb2w::defun? [f <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind f) "list")
    (:wat::core::let [ch (:wat::core::ast->children f)]
      (:wat::core::if (:wat::core::empty? ch) false (:jb2w::symbol-named? (:wat::core::first ch) "defun")))
    false))

(:wat::core::defn :jb2w::defun-name [f <- :wat::WatAST] -> :wat::core::String
  (:wat::core::ast-name (:wat::core::first (:wat::core::rest (:wat::core::ast->children f)))))

(:wat::core::defn :jb2w::defun-formals [f <- :wat::WatAST] -> :jb2w::Forms
  (:wat::core::ast->children (:wat::core::first (:wat::core::rest (:wat::core::rest (:wat::core::ast->children f))))))

(:wat::core::defn :jb2w::defun-body [f <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::first (:wat::core::rest (:wat::core::rest (:wat::core::rest (:wat::core::ast->children f))))))

;; New list and vector nodes, rebuilt from templates.
(:wat::core::defn :jb2w::mklist [children <- :jb2w::Forms] -> :wat::WatAST
  (:wat::core::with-children (:wat::core::quote (t)) children))

(:wat::core::defn :jb2w::mkvec [children <- :jb2w::Forms] -> :wat::WatAST
  (:wat::core::with-children (:wat::core::quote [t]) children))

(:wat::core::defn :jb2w::forms-of [text <- :wat::core::String] -> :jb2w::Forms
  (:wat::core::match (:wat::core::read-string text)
    [:wat::core::ReadOutcome.Forms {:forms fs} (:wat::core::ast->children fs)]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::core::Error/message c))]))

;; Names of the defuns with no formals, the constants.
(:wat::core::defn :jb2w::constants [forms <- :jb2w::Forms acc <- :jb2w::Names] -> :jb2w::Names
  (:wat::core::if (:wat::core::empty? forms)
    acc
    (:wat::core::let [f (:wat::core::first forms)]
      (:jb2w::constants (:wat::core::rest forms)
        (:wat::core::if (:wat::core::if (:jb2w::defun? f) (:wat::core::empty? (:jb2w::defun-formals f)) false)
          (:wat::core::conj acc (:jb2w::defun-name f))
          acc)))))

;; ---- translation

;; Quoted data: every nested quote, in either spelling, becomes (quote x).
(:wat::core::defn :jb2w::datum [d <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind d) "list")
    (:wat::core::let [ch (:wat::core::ast->children d)]
      (:wat::core::if (:wat::core::empty? ch)
        d
        (:wat::core::let [h (:wat::core::first ch)
                          h2 (:wat::core::if (:jb2w::quote-head? h) (:wat::core::symbol-node "quote") (:jb2w::datum h))]
          (:wat::core::with-children d
            (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] h2)
                                (:jb2w::datums (:wat::core::rest ch)))))))
    d))

(:wat::core::defn :jb2w::datums [xs <- :jb2w::Forms] -> :jb2w::Forms
  (:wat::core::if (:wat::core::empty? xs)
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:jb2w::datum (:wat::core::first xs)))
                        (:jb2w::datums (:wat::core::rest xs)))))

(:wat::core::defn :jb2w::quote-it [d <- :wat::WatAST] -> :wat::WatAST
  (:jb2w::mklist (:wat::core::Vector :- [:wat::WatAST] (:wat::core::keyword-node ":wat::core::quote") (:jb2w::datum d))))

;; A J-Bob expression as a wat expression; k holds the constants' names.
(:wat::core::defn :jb2w::expr [e <- :wat::WatAST k <- :jb2w::Names] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::= (:wat::core::ast-kind e) "symbol") (:wat::core::symbol-node (:jb2w::mangle (:wat::core::ast-name e))))
    ((:wat::core::not (:wat::core::= (:wat::core::ast-kind e) "list")) (:jb2w::quote-it e))
    (:else
      (:wat::core::let [ch (:wat::core::ast->children e)
                        h (:wat::core::first ch)
                        args (:wat::core::rest ch)]
        (:wat::core::cond
          ((:jb2w::quote-head? h) (:jb2w::quote-it (:wat::core::first args)))
          ((:jb2w::symbol-named? h "if")
            (:jb2w::mklist (:wat::core::Vector :- [:wat::WatAST]
                             (:wat::core::keyword-node ":wat::core::if")
                             (:jb2w::mklist (:wat::core::Vector :- [:wat::WatAST]
                                              (:wat::core::keyword-node ":jb::true?")
                                              (:jb2w::expr (:wat::core::first args) k)))
                             (:jb2w::expr (:wat::core::first (:wat::core::rest args)) k)
                             (:jb2w::expr (:wat::core::first (:wat::core::rest (:wat::core::rest args))) k))))
          ;; a call to a constant is its value
          ((:wat::core::if (:wat::core::empty? args) (:wat::core::contains? k (:wat::core::ast-name h)) false)
            (:wat::core::keyword-node (:jb2w::fn-name (:wat::core::ast-name h))))
          (:else
            (:jb2w::mklist (:wat::core::concat
                             (:wat::core::Vector :- [:wat::WatAST] (:wat::core::keyword-node (:jb2w::fn-name (:wat::core::ast-name h))))
                             (:jb2w::exprs args k)))))))))

(:wat::core::defn :jb2w::exprs [xs <- :jb2w::Forms k <- :jb2w::Names] -> :jb2w::Forms
  (:wat::core::if (:wat::core::empty? xs)
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:jb2w::expr (:wat::core::first xs) k))
                        (:jb2w::exprs (:wat::core::rest xs) k))))

;; [x <- :wat::WatAST y <- :wat::WatAST ...]
(:wat::core::defn :jb2w::params [formals <- :jb2w::Forms] -> :jb2w::Forms
  (:wat::core::if (:wat::core::empty? formals)
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST]
                          (:wat::core::symbol-node (:jb2w::mangle (:wat::core::ast-name (:wat::core::first formals))))
                          (:wat::core::symbol-node "<-")
                          (:wat::core::keyword-node ":wat::WatAST"))
                        (:jb2w::params (:wat::core::rest formals)))))

;; (defun name () body)       -> (:wat::core::def :jb::name body)
;; (defun name (formals) body) -> (:wat::core::defn :jb::name [params] -> :wat::WatAST body)
(:wat::core::defn :jb2w::defun [f <- :wat::WatAST k <- :jb2w::Names] -> :wat::WatAST
  (:wat::core::let [name (:wat::core::keyword-node (:jb2w::fn-name (:jb2w::defun-name f)))
                    formals (:jb2w::defun-formals f)
                    body (:jb2w::expr (:jb2w::defun-body f) k)]
    (:wat::core::if (:wat::core::empty? formals)
      (:jb2w::mklist (:wat::core::Vector :- [:wat::WatAST] (:wat::core::keyword-node ":wat::core::def") name body))
      (:jb2w::mklist (:wat::core::Vector :- [:wat::WatAST]
                       (:wat::core::keyword-node ":wat::core::defn")
                       name
                       (:jb2w::mkvec (:jb2w::params formals))
                       (:wat::core::symbol-node "->")
                       (:wat::core::keyword-node ":wat::WatAST")
                       body)))))

(:wat::core::defn :jb2w::render [forms <- :jb2w::Forms k <- :jb2w::Names] -> :wat::core::String
  (:wat::core::if (:wat::core::empty? forms)
    ""
    (:wat::core::let [f (:wat::core::first forms)]
      (:wat::string::concat
        (:wat::core::if (:jb2w::defun? f) (:wat::string::concat (:wat::core::ast->source (:jb2w::defun f k)) "\n\n") "")
        (:jb2w::render (:wat::core::rest forms) k)))))

(:wat::core::defn :jb2w::header [from <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat ";; GENERATED by tools/jbob2wat.wat from " from
                        " (BSD 2-Clause, Friedman and Eastlund). Do not edit by hand.\n\n"))

;; ---- the oracle's answers: name -> guile's `write` of the result

(:wat::core::typealias :jb2w::Answers (:wat::core::HashMap :- [:wat::core::String :wat::core::String]))

(:wat::core::defn :jb2w::answers [lines <- (:wat::core::Vector :- [:wat::core::String]) acc <- :jb2w::Answers] -> :jb2w::Answers
  (:wat::core::if (:wat::core::empty? lines)
    acc
    (:wat::core::let [cols (:wat::string::split (:wat::core::first lines) "\t")]
      (:jb2w::answers (:wat::core::rest lines)
        (:wat::core::if (:wat::core::= (:wat::core::length cols) 2)
          (:wat::core::assoc acc (:wat::core::first cols) (:wat::core::first (:wat::core::rest cols)))
          acc)))))

;; ---- chapter programs

(:wat::core::defn :jb2w::loads [from <- :wat::core::i64 to <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::< to from)
    ""
    (:wat::string::concat "(:wat::load-file! \"lib/transcript-ch" (:jb2w::pad2 (:wat::i64::to-string from)) ".wat\")\n"
                          (:jb2w::loads (:wat::core::+ from 1) to))))

(:wat::core::defn :jb2w::checks [forms <- :jb2w::Forms answers <- :jb2w::Answers] -> :wat::core::String
  (:wat::core::if (:wat::core::empty? forms)
    ""
    (:wat::core::let [f (:wat::core::first forms)
                      rest (:jb2w::checks (:wat::core::rest forms) answers)]
      (:wat::core::if (:jb2w::defun? f)
        (:wat::core::let [name (:jb2w::defun-name f)]
          (:wat::core::match (:wat::core::get answers name)
            [:wat::core::Option.Some {:value expected}
              (:wat::string::concat "    ;; " name "\n"
                                    "    (:wat::test::assert-eq (:wat::core::ast->source " (:jb2w::fn-name name) ")\n"
                                    "                           \"" expected "\")\n"
                                    rest)]
            [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "no oracle answer for " name))]))
        rest))))

(:wat::core::defn :jb2w::program [n <- :wat::core::i64 forms <- :jb2w::Forms answers <- :jb2w::Answers] -> :wat::core::String
  (:wat::core::let [nn (:jb2w::pad2 (:wat::i64::to-string n))]
    (:wat::string::concat
      ";; GENERATED by tools/jbob2wat.wat. Do not edit by hand.\n"
      ";; The Little Prover, chapter " (:wat::i64::to-string n) ": every entry of the book's transcript for this chapter\n"
      ";; (vendor/j-bob/little-prover.scm), run through J-Bob translated into wat and checked against\n"
      ";; guile's J-Bob (oracle/prover.expected.tsv). Chapters from 3 on build on the definitions\n"
      ";; before them, so they load every transcript chapter from 3 up to their own.\n"
      ";;\n"
      ";; Run: wat books/little-prover/ch" nn "-transcript.wat   (exit 0 and a final \"ok\" line = pass)\n\n"
      "(:wat::load-file! \"../little-schemer/lib/ch01-toys.wat\")\n"
      "(:wat::load-file! \"../little-schemer/lib/ch04-numbers-games.wat\")\n"
      "(:wat::load-file! \"lib/j-bob-lang.wat\")\n"
      "(:wat::load-file! \"lib/j-bob.wat\")\n"
      (:wat::core::if (:wat::core::< n 3) (:jb2w::loads n n) (:jb2w::loads 3 n))
      "\n(:wat::core::defn :user::main [] -> :wat::core::nil\n  (:wat::core::do\n"
      (:jb2w::checks forms answers)
      "    (:wat::kernel::println \"little-prover ch" nn " transcript: ok\")))\n")))

;; ---- the transcript, chapter by chapter

;; Each piece of the transcript after a ";; Chapter " line starts with the chapter's number,
;; which the reader reads as an int form.
(:wat::core::defn :jb2w::chapters [pieces <- (:wat::core::Vector :- [:wat::core::String]) k <- :jb2w::Names answers <- :jb2w::Answers] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? pieces)
    nil
    (:wat::core::let [forms (:jb2w::forms-of (:wat::core::first pieces))
                      nstr (:wat::core::ast->source (:wat::core::first forms))
                      nn (:jb2w::pad2 nstr)
                      lib (:wat::string::concat "books/little-prover/lib/transcript-ch" nn ".wat")
                      prog (:wat::string::concat "books/little-prover/ch" nn "-transcript.wat")]
      (:wat::core::do
        (:wat::io::write-file lib (:wat::string::concat (:jb2w::header "vendor/j-bob/little-prover.scm") (:jb2w::render forms k)))
        (:wat::io::write-file prog (:jb2w::program (:jb2w::digit nstr) forms answers))
        (:wat::kernel::println (:wat::string::concat "[chapter " nstr "] " lib " + " prog))
        (:jb2w::chapters (:wat::core::rest pieces) k answers)))))

;; A chapter number (the transcript's run from 1 to 9: one digit).
(:wat::core::defn :jb2w::digit [d <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= d "0") 0) ((:wat::core::= d "1") 1) ((:wat::core::= d "2") 2) ((:wat::core::= d "3") 3)
    ((:wat::core::= d "4") 4) ((:wat::core::= d "5") 5) ((:wat::core::= d "6") 6) ((:wat::core::= d "7") 7)
    ((:wat::core::= d "8") 8) ((:wat::core::= d "9") 9) (:else 0)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [jbob (:jb2w::forms-of (:wat::io::read-file "vendor/j-bob/j-bob.scm"))
                    transcript-text (:wat::io::read-file "vendor/j-bob/little-prover.scm")
                    k (:jb2w::constants (:jb2w::forms-of transcript-text)
                                        (:jb2w::constants jbob (:wat::core::HashSet :- [:wat::core::String])))
                    answers (:jb2w::answers (:wat::string::split (:wat::io::read-file "oracle/prover.expected.tsv") "\n")
                                            (:wat::core::HashMap :- [:wat::core::String :wat::core::String]))]
    (:wat::core::do
      (:wat::io::write-file "books/little-prover/lib/j-bob.wat"
        (:wat::string::concat (:jb2w::header "vendor/j-bob/j-bob.scm") (:jb2w::render jbob k)))
      (:wat::kernel::println "[translated] vendor/j-bob/j-bob.scm -> books/little-prover/lib/j-bob.wat")
      (:jb2w::chapters (:wat::core::rest (:wat::string::split transcript-text ";; Chapter ")) k answers))))
