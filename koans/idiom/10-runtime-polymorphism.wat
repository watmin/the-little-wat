;; koans/idiom/10-runtime-polymorphism.wat: the runtime-polymorphism koans that don't port
;; literally (koans/literal/10-runtime-polymorphism.tsv), each said the way wat says it, or
;; marked as having no wat route. Keyword spelling throughout, so the checker sees every call
;; (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; A defn has one arity (multi-arity overloads are "out of scope today", USER-GUIDE.md, arc 166)
;; and no rest parameter, so greet is one name per arity, and the rest is a Vector. A map of a
;; kind and a name is a record, and its kind may be absent, so it is an Option. A multimethod's
;; dispatch becomes a match and a cond; that dispatch is closed, where a multimethod is open to
;; new methods anywhere.
;;
;; Run from the repository root: wat koans/idiom/10-runtime-polymorphism.wat

(:wat::core::defn :koan::greet0 [] -> :wat::core::String "Hello!")

(:wat::core::defn :koan::greet1 [a <- :wat::core::String] -> :wat::core::String (:wat::string::concat "Hello, " a "."))

(:wat::core::defn :koan::greet-all [a <- :wat::core::String more <- (:wat::core::Vector :- [:wat::core::String])] -> :wat::core::String
  (:wat::string::concat "Hello to all: " (:wat::string::join ", " (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] a) more)) "!"))

(:wat::core::defrecord :koan::Animal [kind <- (:wat::core::Option :- [:wat::core::keyword])  name <- :wat::core::String])

;; widened constructors: a bare variant keeps its narrowed type (F-019)
(:wat::core::defn :koan::kind [k <- :wat::core::keyword] -> (:wat::core::Option :- [:wat::core::keyword]) (:wat::core::Option.Some {:value k}))
(:wat::core::defn :koan::no-kind [] -> (:wat::core::Option :- [:wat::core::keyword]) (:wat::core::Option.None {}))

(:wat::core::defn :koan::sound [a <- :koan::Animal] -> :wat::core::String
  (:wat::core::let [name (:koan::Animal/name a)]
    (:wat::core::match (:koan::Animal/kind a)
      [:wat::core::Option.Some {:value k}
        (:wat::core::cond
          ((:wat::core::= k :dog) (:wat::string::concat name " barks."))
          ((:wat::core::= k :cat) (:wat::string::concat name " meows."))
          (:else (:wat::string::concat name " is quiet.")))]
      [:wat::core::Option.None {} (:wat::string::concat name " is quiet.")])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::greet0) "Hello!") ; row 1
    (:wat::test::assert-eq (:koan::greet1 "Ada") "Hello, Ada.") ; row 2
    (:wat::test::assert-eq (:koan::greet-all "Ada" ["Bob" "Cy"]) "Hello to all: Ada, Bob, Cy!") ; row 3
    (:wat::test::assert-eq (:koan::sound (:koan::Animal :kind (:koan::kind :dog) :name "Rex")) "Rex barks.") ; row 4
    (:wat::test::assert-eq (:koan::sound (:koan::Animal :kind (:koan::kind :cat) :name "Tom")) "Tom meows.") ; row 5
    (:wat::test::assert-eq (:koan::sound (:koan::Animal :kind (:koan::kind :fish) :name "Nemo")) "Nemo is quiet.") ; row 6
    (:wat::test::assert-eq (:koan::sound (:koan::Animal :kind (:koan::no-kind) :name "Anon")) "Anon is quiet.") ; row 7
    (:wat::kernel::println "koans idiom 10-runtime-polymorphism: ok")))
