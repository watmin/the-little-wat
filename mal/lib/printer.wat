;; mal/lib/printer.wat: mal's printer. Needs lib/types.wat. No main. Keyword spelling throughout.

(:wat::core::defn :mal::escape-from [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:wat::core::let [c (:mal::char-at s i)]
      (:mal::escape-from s (:wat::core::+ i 1) n
        (:wat::string::concat acc
          (:wat::core::cond
            ((:wat::core::= c "\\") "\\\\")
            ((:wat::core::= c "\"") "\\\"")
            ((:wat::core::= c "\n") "\\n")
            (:else c)))))))

(:wat::core::defn :mal::pr-seq [open <- :wat::core::String items <- :mal::Vals close <- :wat::core::String readably <- :wat::core::bool] -> :wat::core::String
  (:wat::string::concat open
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [x <- :mal::Val] -> :wat::core::String (:mal::pr-str x readably)) items))
    close))

(:wat::core::defn :mal::pr-str [v <- :mal::Val readably <- :wat::core::bool] -> :wat::core::String
  (:wat::core::match v
    [:mal::Val.Nil {} "nil"]
    [:mal::Val.True {} "true"]
    [:mal::Val.False {} "false"]
    [:mal::Val.Int {:n n} (:wat::i64::to-string n)]
    [:mal::Val.Str {:s s}
      (:wat::core::if readably
        (:wat::string::concat "\"" (:mal::escape-from s 0 (:wat::string::length s) "") "\"")
        s)]
    [:mal::Val.Sym {:name name} name]
    [:mal::Val.Kw {:name name} (:wat::string::concat ":" name)]
    [:mal::Val.List {:items xs} (:mal::pr-seq "(" xs ")" readably)]
    [:mal::Val.Vec {:items xs} (:mal::pr-seq "[" xs "]" readably)]
    [:mal::Val.Map {:kvs xs} (:mal::pr-seq "{" xs "}" readably)]
    [:mal::Val.Builtin {:name name} (:wat::string::concat "#<builtin " name ">")]))

;; what the REPL prints for an evaluation
(:wat::core::defn :mal::pr-res [r <- :mal::Res] -> :wat::core::String
  (:wat::core::match r
    [:mal::Res.Ok {:v v} (:mal::pr-str v true)]
    [:mal::Res.Err {:e e} (:wat::string::concat "Error: " (:mal::pr-str e true))]))
