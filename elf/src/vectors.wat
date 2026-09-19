;; Vectors and records, compiled -- half of what elf/census.wat says stands between this
;; compiler and compiling itself.
;;
;; They are the SAME object in memory: `[count:8][slot:8]...`, every slot a machine word, which
;; is also what a String is if you read its bytes as the payload. So one layout answers `length`
;; (a peek at the header), `nth` and a field read (the same indexed load), and `conj` and `assoc`
;; (the same copy). The only difference is that a record's field names are known at compile time,
;; so its accesses are at constant offsets.
;;
;; Everything is copy-on-write, because F-104 is true in machine code too: there is no positional
;; update, so `assoc` makes a new one.
;;
;; **The two declarations below are in the keyword spelling and the rest of the file is not.**
;; That is not a style choice: `(wat.core/typealias user/Row ...)` is refused with "name must be
;; a keyword; got symbol", and `(wat.core/defrecord user/Point ...)` dies inside the macro. That
;; is F-122, and this file is the seam.
;;
;; Run both ways; they must agree.

(:wat::core::defrecord :user::Point
  [x <- :wat::core::i64  y <- :wat::core::i64  label <- :wat::core::String])

(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/range-to [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/> i n) acc
    (user/range-to n (wat.core/+ i 1) (wat.core/conj acc i))))

(wat.core/defn user/dist2 [p :- :user::Point] :- wat.type/i64
  (wat.core/+ (wat.core/* (:user::Point/x p) (:user::Point/x p))
              (wat.core/* (:user::Point/y p) (:user::Point/y p))))

(wat.core/defn user/main [] :- wat.type/nil
  ;; a literal vector, its length and its elements
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64] 10 20 30 40)]
    (wat.kernel/println (wat.core/length v))
    (wat.kernel/println (wat.core/nth v 0))
    (wat.kernel/println (wat.core/nth v 3))
    (wat.kernel/println (user/sum v 0 0))
    ;; and there is no positional update to try: wat's own `assoc` refuses a Vector (F-104),
    ;; so the compiler refuses it too rather than becoming a superset of the language
    (wat.kernel/println (wat.core/nth (wat.core/conj v 50) 4)))

  ;; conj a thousand times, which is a thousand copies -- 4 MB of bump allocation, released
  ;; because the whole let is a discarded statement (C-120)
  (wat.core/let [r (user/range-to 1000 1 (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println (wat.core/length r))
    (wat.kernel/println (user/sum r 0 0)))

  ;; a vector of strings keeps its element type, so println still picks the right routine
  (wat.core/let [names (wat.core/Vector :- [wat.type/String] "ada" "grace" "barbara")]
    (wat.kernel/println (wat.core/nth names 1))
    (wat.kernel/println (wat.core/length names)))

  ;; records: constructed out of declaration order, read by field, copied by assoc
  (wat.core/let [p (:user::Point :label "origin-ish" :y 4 :x 3)
                 q (wat.core/assoc p :y 12)]
    (wat.kernel/println (:user::Point/x p))
    (wat.kernel/println (:user::Point/y p))
    (wat.kernel/println (:user::Point/label p))
    (wat.kernel/println (user/dist2 p))
    (wat.kernel/println (user/dist2 q))
    (wat.kernel/println (:user::Point/y p))
    (wat.kernel/println (:user::Point/label q))))
