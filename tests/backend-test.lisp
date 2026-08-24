(in-package #:rpc-backend-sse/tests)

(defun %echo (method params)
  (cond
    ((equal method "echo") params)
    ((equal method "sum") (+ (elt params 0) (elt params 1)))
    (t (error 'rpc-protocol:rpc-method-not-found))))

(defun %free-port ()
  (let* ((sock (usocket:socket-listen "127.0.0.1" 0 :reuseaddress t))
         (port (usocket:get-local-port sock)))
    (usocket:socket-close sock)
    port))

(defun %bind ()
  (http-server-backend-hunchentoot:use-hunchentoot-backend)
  (setf http-protocol:*http-backend*
        (http-backend-dexador:make-dexador-backend))
  (sse-backend-http:use-http-sse-backend))

(deftest transport-class
  (ok (typep (rpc-backend-sse:make-sse-rpc-transport)
             'rpc-backend-sse:sse-rpc-transport)))

(deftest make-rpc-sse-app-in-process
  (let* ((app (rpc-backend-sse:make-rpc-sse-app #'%echo :path "/rpc"))
         (body (rpc-protocol:encode-request "echo" "hi" :id 1))
         (env (list :request-method :post
                    :path-info "/rpc"
                    :raw-body body
                    :headers (make-hash-table :test 'equal)))
         (res (funcall app env))
         (wire (apply #'concatenate 'string (third res)))
         (evs (with-input-from-string (in wire)
                (sse-protocol:collect-sse-events in)))
         (msg (rpc-protocol:decode-message
               (sse-protocol:sse-event-data (first evs)))))
    (ok (= 200 (first res)))
    (ok (equal "hi" (gethash "result" msg)))))

(deftest live-sse-rpc
  (%bind)
  (let ((port (%free-port)))
    (http-server-protocol:with-server
        (s (rpc-backend-sse:make-rpc-sse-app #'%echo :path "/rpc")
           :host "127.0.0.1" :port port)
      (sleep 0.2)
      (let ((tx (rpc-backend-sse:make-sse-rpc-transport
                 :url (format nil "http://127.0.0.1:~a/rpc" port))))
        (ok (equal "hi" (rpc-protocol:rpc-call "echo" "hi" :transport tx :id 1)))
        (ok (= 3 (rpc-protocol:rpc-call "sum" #(1 2) :transport tx :id 2)))
        (ok (signals (rpc-protocol:rpc-call "nope" nil :transport tx :id 3)
                     'rpc-protocol:rpc-error))))))
