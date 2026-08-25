(defsystem "rpc-backend-sse"
  :version "0.1.1"
  :description "SSE JSON-RPC transport for rpc-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("rpc-protocol" "rpc-protocol-json" "sse-protocol" "sse-backend-clack" "babel")
  :properties (:cl-repo (:ci (:with ("dissect") :sources (("dissect" :ql)))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "rpc-backend-sse/tests"))))

(defsystem "rpc-backend-sse/tests"
  :depends-on ("rpc-backend-sse"
               "sse-backend-http"
               "http-server-backend-hunchentoot"
               "http-backend-dexador"
               "rove"
               "usocket")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
