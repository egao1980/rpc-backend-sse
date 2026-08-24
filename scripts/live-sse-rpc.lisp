;;;; Dogfood SSE RPC: clack emit × http consume.
;;;;   sbcl --load scripts/live-sse-rpc.lisp

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&live-sse-rpc failed: ~a~%" c)
        (uiop:quit 1)))

(defun %here ()
  (uiop:pathname-directory-pathname
   (or *load-truename* *compile-file-truename* (uiop:getcwd))))

(defun %workspace ()
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-parent-directory-pathname (%here))))

(dolist (name '("rpc-protocol" "rpc-backend-sse" "sse-protocol"
                "sse-backend-clack" "sse-backend-http" "http-protocol"
                "http-server-protocol" "http-backend-dexador"))
  (pushnew (merge-pathnames (format nil "~a/" name) (%workspace))
           asdf:*central-registry* :test #'equal))

(asdf:load-system "rpc-backend-sse")
(asdf:load-system "sse-backend-http")
(asdf:load-system "http-server-backend-hunchentoot")
(asdf:load-system "http-backend-dexador")
(asdf:load-system "usocket")

(http-server-backend-hunchentoot:use-hunchentoot-backend)
(setf http-protocol:*http-backend*
      (http-backend-dexador:make-dexador-backend))
(sse-backend-http:use-http-sse-backend)

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

(let ((port (%free-port)))
  (http-server-protocol:with-server
      (s (rpc-backend-sse:make-rpc-sse-app #'%echo :path "/rpc")
         :host "127.0.0.1" :port port)
    (sleep 0.2)
    (let ((tx (rpc-backend-sse:make-sse-rpc-transport
               :url (format nil "http://127.0.0.1:~a/rpc" port))))
      (unless (equal "hi" (rpc-protocol:rpc-call "echo" "hi" :transport tx :id 1))
        (format *error-output* "~&FAIL: echo~%")
        (uiop:quit 1))
      (unless (= 3 (rpc-protocol:rpc-call "sum" #(1 2) :transport tx :id 2))
        (format *error-output* "~&FAIL: sum~%")
        (uiop:quit 1)))))

(format t "~&; live-sse-rpc ok~%")
(uiop:quit 0)
