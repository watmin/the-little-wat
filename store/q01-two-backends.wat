;; wat's two Store backends, checked against each other from OUTSIDE wat-rs's test tree.
;;
;; wat ships a backend-agnostic storage contract, :wat::query::Store — a DynamoDB-shaped
;; (pk, sk, data) narrow waist with named GSIs — and TWO services that satisfy it:
;; :wat::query::mem-store and :wat::query::sqlite-store. wat/query/mem.wat says the in-memory one
;; is "dual-purpose … a genuine in-memory backend AND the oracle sqlite will be
;; differential-tested against — correct-by-construction, not a canned stub".
;;
;; So this suite needs no external oracle: the two backends check each other. The same operations
;; are driven through the same `:wat::query::Store` surface, and every line one answers must be
;; the other's.
;;
;; WHY THIS IS NOT JUST wat-rs's OWN GATE. wat-rs already has
;; tests/rete/probe_arc278_sqlite_store_differential.{wat,rs}, which does exactly this comparison
;; inside their harness. What it does not test is whether an ORDINARY PROGRAM can do it: no
;; deftest, no fixture loader, no co-located .rs. That is the user's position, and it is the
;; position this repository is for.
;;
;; Where the backends are MEANT to differ they are not compared: mem-store's ensure-schema is a
;; deliberate no-op ("no physical schema to establish") while sqlite-store's is where CREATE
;; TABLE happens.
;;
;; Run from the repository root (it reads nothing; both stores are baked into the binary):
;;   wat store/q01-two-backends.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :st::Rows (:wat::core::Vector :- [:wat::query::StoredRow]))
(:wat::core::typealias :st::Keys (:wat::core::HashMap :- [:wat::core::String :wat::query::IndexKey]))

;; ---- the workload, written ONCE against the surface and run against both backends

(:wat::core::defn :st::no-keys [] -> :st::Keys
  (:wat::core::HashMap :- [:wat::core::String :wat::query::IndexKey]))

(:wat::core::defn :st::by-v [isk <- :wat::core::String] -> :st::Keys
  (:wat::core::HashMap :- [:wat::core::String :wat::query::IndexKey]
    "by-v" (:wat::query::IndexKey :ipk "u#1" :isk isk)))

;; five rows on one partition; two of them project the GSI
(:wat::core::defn :st::rows [] -> :st::Rows
  (:wat::core::Vector :- [:wat::query::StoredRow]
    (:wat::query::StoredRow :pk "u#1" :sk "a" :data "{:v 1}" :index-keys (:st::by-v "v1"))
    (:wat::query::StoredRow :pk "u#1" :sk "b" :data "{:v 2}" :index-keys (:st::no-keys))
    (:wat::query::StoredRow :pk "u#1" :sk "c" :data "{:v 3}" :index-keys (:st::by-v "v2"))
    (:wat::query::StoredRow :pk "u#1" :sk "d" :data "{:v 4}" :index-keys (:st::no-keys))
    (:wat::query::StoredRow :pk "u#1" :sk "e" :data "{:v 5}" :index-keys (:st::no-keys))))

(:wat::core::defn :st::schema-req [] -> :wat::query::Store::EnsureSchemaRequest
  (:wat::query::Store::EnsureSchemaRequest
    :table   (:wat::query::TableSchema :pk "pk" :sk "sk")
    :indexes (:wat::core::Vector :- [:wat::query::IndexSchema]
               (:wat::query::IndexSchema :name "by-v" :pk "pk" :sk "sk" :ipk "ipk" :isk "isk"))))

;; ---- reading an outcome back. Four RecvOutcome arms per call, every call, because a message
;; ---- can be Lost, Stopped or Closed and the checker makes you say so each time.

(:wat::core::defn :st::ensured [store <- :wat::query::Store] -> :wat::core::String
  (:wat::core::match (:wat::query::Store/ensure-schema store (:st::schema-req))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:wat::query::Store::EnsureSchemaResponse.Success {} "schema ok"]
        [:wat::query::Store::EnsureSchemaResponse.Constraint {:err _e} "schema Constraint"]
        [:wat::query::Store::EnsureSchemaResponse.Fatal {:err _e} "schema Fatal"]
        [:wat::query::Store::EnsureSchemaResponse.RequestTooLarge {:bytes _b :cap _c} "schema TooLarge"]
        [:wat::query::Store::EnsureSchemaResponse.RequestMalformed {:path _p :expected _e :got _g} "schema Malformed"])]
    [:wat::kernel::RecvOutcome.Lost {:cause _c} "lost"]
    [:wat::kernel::RecvOutcome.Stopped {} "stopped"]
    [:wat::kernel::RecvOutcome.Closed {} "closed"]))

(:wat::core::defn :st::put [store <- :wat::query::Store] -> :wat::core::String
  (:wat::core::match (:wat::query::Store/put store (:wat::query::Store::PutRequest :rows (:st::rows)))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:wat::query::Store::PutResponse.Success {} "put ok"]
        [:wat::query::Store::PutResponse.Constraint {:err _e} "put Constraint"]
        [:wat::query::Store::PutResponse.Transient {:err _e} "put Transient"]
        [:wat::query::Store::PutResponse.Fatal {:err _e} "put Fatal"]
        [:wat::query::Store::PutResponse.RequestTooLarge {:bytes _b :cap _c} "put TooLarge"]
        [:wat::query::Store::PutResponse.RequestMalformed {:path _p :expected _e :got _g} "put Malformed"])]
    [:wat::kernel::RecvOutcome.Lost {:cause _c} "lost"]
    [:wat::kernel::RecvOutcome.Stopped {} "stopped"]
    [:wat::kernel::RecvOutcome.Closed {} "closed"]))

;; a scan page, rendered as "sk,sk,sk|cursor" so two backends can be compared as strings
(:wat::core::defn :st::render-rows [rows <- (:wat::core::Vector :- [:wat::query::Row])] -> :wat::core::String
  (:wat::string::join "," (:wat::core::mapv :wat::query::Row/sk rows)))

(:wat::core::defn :st::render-cursor [c <- (:wat::core::Option :- [:wat::core::String])] -> :wat::core::String
  (:wat::core::match c
    [:wat::core::Option.Some {:value s} s]
    [:wat::core::Option.None {} "<none>"]))

(:wat::core::defn :st::scan [store <- :wat::query::Store cursor <- (:wat::core::Option :- [:wat::core::String])] -> :wat::core::String
  (:wat::core::match (:wat::query::Store/scan store
                       (:wat::query::Store::ScanRequest :pk "u#1" :sk-lo "a" :sk-hi "z" :limit 2 :cursor cursor))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:wat::query::Store::ScanResponse.Success {:rows rows :cursor next}
          (:wat::string::concat (:st::render-rows rows) "|" (:st::render-cursor next))]
        [:wat::query::Store::ScanResponse.Transient {:err _e} "scan Transient"]
        [:wat::query::Store::ScanResponse.Fatal {:err _e} "scan Fatal"]
        [:wat::query::Store::ScanResponse.RequestTooLarge {:bytes _b :cap _c} "scan TooLarge"]
        [:wat::query::Store::ScanResponse.RequestMalformed {:path _p :expected _e :got _g} "scan Malformed"])]
    [:wat::kernel::RecvOutcome.Lost {:cause _c} "lost"]
    [:wat::kernel::RecvOutcome.Stopped {} "stopped"]
    [:wat::kernel::RecvOutcome.Closed {} "closed"]))

;; the cursor a scan page ends on, so the next page can resume from it
(:wat::core::defn :st::scan-cursor [store <- :wat::query::Store cursor <- (:wat::core::Option :- [:wat::core::String])] -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::match (:wat::query::Store/scan store
                       (:wat::query::Store::ScanRequest :pk "u#1" :sk-lo "a" :sk-hi "z" :limit 2 :cursor cursor))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:wat::query::Store::ScanResponse.Success {:rows _rows :cursor next} next]
        [:wat::query::Store::ScanResponse.Transient {:err _e} (:wat::core::Option.None {})]
        [:wat::query::Store::ScanResponse.Fatal {:err _e} (:wat::core::Option.None {})]
        [:wat::query::Store::ScanResponse.RequestTooLarge {:bytes _b :cap _c} (:wat::core::Option.None {})]
        [:wat::query::Store::ScanResponse.RequestMalformed {:path _p :expected _e :got _g} (:wat::core::Option.None {})])]
    [:wat::kernel::RecvOutcome.Lost {:cause _c} (:wat::core::Option.None {})]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::core::Option.None {})]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::core::Option.None {})]))

(:wat::core::defn :st::scan-index [store <- :wat::query::Store] -> :wat::core::String
  (:wat::core::match (:wat::query::Store/scan-index store
                       (:wat::query::Store::ScanIndexRequest :index "by-v" :ipk "u#1"
                         :isk-lo "v0" :isk-hi "v9" :limit 10 :cursor (:wat::core::Option.None {})))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:wat::query::Store::ScanIndexResponse.Success {:rows rows :cursor next}
          (:wat::string::concat
            (:wat::string::join "," (:wat::core::mapv :wat::query::IndexRow/isk rows))
            "|" (:st::render-cursor next))]
        [:wat::query::Store::ScanIndexResponse.Transient {:err _e} "index Transient"]
        [:wat::query::Store::ScanIndexResponse.Fatal {:err _e} "index Fatal"]
        [:wat::query::Store::ScanIndexResponse.RequestTooLarge {:bytes _b :cap _c} "index TooLarge"]
        [:wat::query::Store::ScanIndexResponse.RequestMalformed {:path _p :expected _e :got _g} "index Malformed"])]
    [:wat::kernel::RecvOutcome.Lost {:cause _c} "lost"]
    [:wat::kernel::RecvOutcome.Stopped {} "stopped"]
    [:wat::kernel::RecvOutcome.Closed {} "closed"]))

;; ---- the whole workload, written once, run against whichever backend it is handed.
;; ---- This is the thing worth proving: ONE function, two services, because a dialed peer of a
;; ---- `:satisfies Store` service IS a Store.
(:wat::core::defn :st::run-ops [store <- :wat::query::Store] -> :st::Lines
  (:wat::core::let [ensured (:st::ensured store)
                    put     (:st::put store)
                    page1   (:st::scan store (:wat::core::Option.None {}))
                    cur1    (:st::scan-cursor store (:wat::core::Option.None {}))
                    page2   (:st::scan store cur1)
                    cur2    (:st::scan-cursor store cur1)
                    page3   (:st::scan store cur2)
                    idx     (:st::scan-index store)]
    (:wat::core::Vector :- [:wat::core::String]
      put page1 page2 page3 idx)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  ;; start + connect stay INLINE. wat-rs's own fixture says why: "spawn scope law: a helper that
  ;; returns the peer leaves the service thread dead" — which is F-052, confirmed in their words.
  ;; It is also why each dial below is one long line rather than a named helper.
  (:wat::core::let
    [mh (:wat::query::mem-store/start :locus (:wat::spawn::thread)
          :record (:wat::query::mem-store::Record :rows (:wat::core::PersistentVector)))
     mem (:wat::core::match (:wat::kernel::connect (:wat::query::mem-store::Handle/addr mh))
           [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
           [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
           [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
           [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])
     mem-lines (:st::run-ops mem)

     sh (:wat::query::sqlite-store/start :locus (:wat::spawn::thread)
          :record (:wat::query::sqlite-store::Record
                    :path ":memory:"
                    :index-names (:wat::core::Vector :- [:wat::core::String] "by-v")))
     sql (:wat::core::match (:wat::kernel::connect (:wat::query::sqlite-store::Handle/addr sh))
           [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
           [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
           [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
           [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])
     sql-lines (:st::run-ops sql)]

    (:st::check-agree "store q01 two backends" "mem-store" mem-lines "sqlite-store" sql-lines)))
