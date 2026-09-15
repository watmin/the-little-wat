;; A Little Java, A Few Patterns, chapter 10 (The State of Things to Come).
;; Java's pie man is an object whose field changes: it keeps one pie, changes it, and answers
;; how many of a topping it holds after each change; and a visitor changes a pie in place,
;; so that every reference to that pie sees the change.
;;
;; wat has no mutable fields; mutable state lives on services. So the pie man's pie lives in
;; a PieCell, a service holding one pie (the Seasoned Schemer's cell.wat, typed for pies), and
;; the pie man's methods are functions that get the pie, make the changed one, and put it back.
;; Two pie men are two cells. A second reference to the same cell is the alias, and sees a
;; change made through the first; nothing else can. (Java's pie == alias, identity, has no
;; counterpart: wat values have none.)
;; Results are printed as the Java oracle's are
;; (oracle/java/ch10-the-state-of-things-to-come.java, run by tools/java-oracle.sh), and every
;; one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch10-the-state-of-things-to-come.wat

(:wat::load-file! "lib/check.wat")

;; ---- PieCell: a service holding one pie (as books/seasoned-schemer/lib/cell.wat, typed)
;;
;; The pie datatype itself is declared inside the service's surface: a Peer surface that owns
;; :messages must declare every non-stdlib type its messages reach, so a service can ship them
;; across a process fork. So the surface comes first, and PieD with it.

(:wat::core::defsurface :lj::PieCell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defenum :lj::PieD :wat::enum::Pure
     :Bot []
     :Top [t <- :wat::core::i64  r <- :lj::PieD])
   (:wat::core::defrecord :lj::PieCell::GetRequest [])
   (:wat::core::defenum :lj::PieCell::GetResponse :wat::enum::Pure
     :Ok               [value <- :lj::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :lj::PieCell::PutRequest [value <- :lj::PieD])
   (:wat::core::defenum :lj::PieCell::PutResponse :wat::enum::Pure
     :Ok               [value <- :lj::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :lj::PieCell  req <- :lj::PieCell::GetRequest] -> :lj::PieCell::GetResponse :max-request-bytes 524288)
   (put [self <- :lj::PieCell  req <- :lj::PieCell::PutRequest] -> :lj::PieCell::PutResponse :max-request-bytes 524288)])


(:wat::core::defn :lj::bot [] -> :lj::PieD (:lj::PieD.Bot {}))
(:wat::core::defn :lj::top [t <- :wat::core::i64 r <- :lj::PieD] -> :lj::PieD (:lj::PieD.Top {:t t :r r}))

(:wat::core::defn :lj::occurs [p <- :lj::PieD a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match p
    [:lj::PieD.Bot {} 0]
    [:lj::PieD.Top {:t t :r r} (:wat::core::if (:wat::core::= t a) (:wat::core::+ 1 (:lj::occurs r a)) (:lj::occurs r a))]))

(:wat::core::defn :lj::rem [p <- :lj::PieD o <- :wat::core::i64] -> :lj::PieD
  (:wat::core::match p
    [:lj::PieD.Bot {} (:lj::bot)]
    [:lj::PieD.Top {:t t :r r} (:wat::core::if (:wat::core::= t o) (:lj::rem r o) (:lj::top t (:lj::rem r o)))]))

;; Java's SubstInPlaceV rewrites the pie's fields; here the changed pie is a new value
(:wat::core::defn :lj::subst [p <- :lj::PieD n <- :wat::core::i64 o <- :wat::core::i64] -> :lj::PieD
  (:wat::core::match p
    [:lj::PieD.Bot {} (:lj::bot)]
    [:lj::PieD.Top {:t t :r r} (:lj::top (:wat::core::if (:wat::core::= t o) n t) (:lj::subst r n o))]))

(:wat::core::defn :lj::show-pie [p <- :lj::PieD] -> :wat::core::String
  (:wat::core::match p
    [:lj::PieD.Bot {} "(Bot)"]
    [:lj::PieD.Top {:t t :r r} (:wat::string::concat "(Top " (:wat::i64::to-string t) " " (:lj::show-pie r) ")")]))

(:wat::service::defservice :lj::pie-cell
  :satisfies :lj::PieCell
  :durable [value <- :lj::PieD]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:lj::PieCell::GetResponse.Ok {:value (:lj::pie-cell::Record/value (:lj::pie-cell::State/durable s))})}))
   (put [s ctx req]
     (:wat::core::let [v (:lj::PieCell::PutRequest/value req)]
       (:wat::service::Outcome.Reply
         {:state (:lj::pie-cell::State :durable (:lj::pie-cell::Record :value v))
          :reply (:lj::PieCell::PutResponse.Ok {:value v})})))])

(:wat::core::defstruct :lj::PieCellRef
  [handle <- :lj::pie-cell::Handle
   peer   <- :lj::PieCell])

(:wat::core::defn :lj::new-pie-cell [p <- :lj::PieD] -> :lj::PieCellRef
  (:wat::core::let
    [h (:lj::pie-cell/start :locus (:wat::spawn::thread) :record (:lj::pie-cell::Record :value p))
     peer (:wat::core::match (:wat::kernel::connect (:lj::pie-cell::Handle/addr h))
            [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
            [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
            [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
            [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:lj::PieCellRef :handle h :peer peer)))

(:wat::core::defn :lj::cell-get [c <- :lj::PieCellRef] -> :lj::PieD
  (:wat::core::match (:lj::PieCell/get (:lj::PieCellRef/peer c) (:lj::PieCell::GetRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:lj::PieCell::GetResponse.Ok {:value v} v]
        [:lj::PieCell::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "pie cell get: request too large")]
        [:lj::PieCell::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "pie cell get: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "pie cell get: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "pie cell get: closed")]))

(:wat::core::defn :lj::cell-put! [c <- :lj::PieCellRef p <- :lj::PieD] -> :lj::PieD
  (:wat::core::match (:lj::PieCell/put (:lj::PieCellRef/peer c) (:lj::PieCell::PutRequest :value p))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:lj::PieCell::PutResponse.Ok {:value v} v]
        [:lj::PieCell::PutResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "pie cell put: request too large")]
        [:lj::PieCell::PutResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "pie cell put: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "pie cell put: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "pie cell put: closed")]))

;; ---- the pie man: each method gets the pie, changes it, puts it back, and counts

(:wat::core::defn :lj::occ-top [y <- :lj::PieCellRef o <- :wat::core::i64] -> :wat::core::i64
  (:lj::occurs (:lj::cell-get y) o))

(:wat::core::defn :lj::add-top! [y <- :lj::PieCellRef t <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do (:lj::cell-put! y (:lj::top t (:lj::cell-get y))) (:lj::occ-top y t)))

(:wat::core::defn :lj::rem-top! [y <- :lj::PieCellRef t <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do (:lj::cell-put! y (:lj::rem (:lj::cell-get y) t)) (:lj::occ-top y t)))

(:wat::core::defn :lj::subst-top! [y <- :lj::PieCellRef n <- :wat::core::i64 o <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do (:lj::cell-put! y (:lj::subst (:lj::cell-get y) n o)) (:lj::occ-top y n)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    pie (:wat::core::fn [c <- :lj::PieCellRef] -> :wat::core::String (:lj::show-pie (:lj::cell-get c)))
                    y (:lj::new-pie-cell (:lj::bot))
                    z (:lj::new-pie-cell (:lj::bot))
                    shared (:lj::new-pie-cell (:lj::top 1 (:lj::top 2 (:lj::top 1 (:lj::bot)))))
                    alias shared]
    (:lj::check-chapter "oracle/java/ch10-the-state-of-things-to-come.expected"
                        "little-java ch10 the-state-of-things-to-come"
                        (:wat::core::Vector :- [:wat::core::String]
                          (int (:lj::add-top! y 3))
                          (int (:lj::add-top! y 2))
                          (int (:lj::add-top! y 3))
                          (pie y)
                          (int (:lj::occ-top y 3))
                          (int (:lj::subst-top! y 5 3))
                          (pie y)
                          (int (:lj::rem-top! y 5))
                          (pie y)
                          (int (:lj::add-top! y 7))
                          ;; two pie men are two pies
                          (int (:lj::add-top! z 7))
                          (pie y)
                          (pie z)
                          ;; a change made through one reference is seen through the other
                          (:wat::core::do (:lj::cell-put! shared (:lj::subst (:lj::cell-get shared) 9 1)) (pie alias))))))
