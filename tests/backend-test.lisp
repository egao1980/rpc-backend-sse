(in-package #:rpc-backend-sse/tests)

(deftest transport-class
  (ok (typep (rpc-backend-sse:make-sse-rpc-transport) 'rpc-backend-sse:sse-rpc-transport)))
