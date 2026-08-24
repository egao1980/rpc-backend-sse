(in-package #:rpc-backend-sse)

(defclass sse-rpc-transport (rpc-protocol:rpc-transport)
  ((url :initarg :url :initform nil :accessor transport-url)
   (next-id :initform 0 :accessor transport-next-id)))

(defun make-sse-rpc-transport (&key url)
  (make-instance 'sse-rpc-transport :url url))

(defun use-sse-rpc-transport (&key url)
  (setf rpc-protocol:*rpc-transport* (make-sse-rpc-transport :url url)))

(defun %octets-to-string (octets)
  (babel:octets-to-string octets :encoding :utf-8))

(defun %slurp-stream (stream)
  (if (and (open-stream-p stream)
           (ignore-errors
             (let ((et (stream-element-type stream)))
               (and et (subtypep et 'character)))))
      (with-output-to-string (out)
        (loop for c = (read-char stream nil :eof)
              until (eq c :eof)
              do (write-char c out)))
      (let ((bytes (make-array 0 :element-type '(unsigned-byte 8)
                                  :adjustable t :fill-pointer 0)))
        (loop for b = (read-byte stream nil :eof)
              until (eq b :eof)
              do (vector-push-extend b bytes))
        (%octets-to-string bytes))))

(defun slurp-env-body (env)
  (let ((raw (getf env :raw-body)))
    (cond
      ((null raw) "")
      ((stringp raw) raw)
      ((and (vectorp raw) (not (stringp raw)))
       (%octets-to-string raw))
      ((streamp raw) (%slurp-stream raw))
      (t ""))))

(defun %raise-rpc (msg)
  (let ((err (gethash "error" msg)))
    (if err
        (error 'rpc-protocol:rpc-error
               :code (or (gethash "code" err) rpc-protocol:+internal-error+)
               :message (gethash "message" err)
               :data (gethash "data" err))
        (gethash "result" msg))))

(defun %dispatch-wire (handler body)
  (let* ((msg (if (plusp (length body))
                  (rpc-protocol:decode-message body)
                  (error 'rpc-protocol:rpc-error
                         :message "empty JSON-RPC body"
                         :code rpc-protocol:+invalid-request+)))
         (method (gethash "method" msg))
         (params (gethash "params" msg))
         (id (gethash "id" msg)))
    (unless method
      (return-from %dispatch-wire
        (rpc-protocol:encode-error-response
         rpc-protocol:+invalid-request+ "missing method" :id id)))
    (handler-case
        (let ((result (funcall handler method params)))
          (if id
              (rpc-protocol:encode-response result :id id)
              (rpc-protocol:encode-notification "ack" t)))
      (rpc-protocol:rpc-error (c)
        (rpc-protocol:encode-error-response
         (rpc-protocol:rpc-error-code c)
         (or (rpc-protocol:rpc-error-message c) "rpc error")
         :id id :data (rpc-protocol:rpc-error-data c)))
      (error (c)
        (rpc-protocol:encode-error-response
         rpc-protocol:+internal-error+ (format nil "~a" c) :id id)))))

(defun make-rpc-sse-app (handler &key (path nil))
  "Clack app: POST JSON-RPC, respond with one SSE event whose data is the reply."
  (sse-backend-clack:make-sse-app
   (lambda (env)
     (let ((wire (%dispatch-wire handler (slurp-env-body env))))
       (list (sse-protocol:make-sse-event :event "message" :data wire))))
   :path path))

(defmethod rpc-protocol:backend-rpc-call
    ((transport sse-rpc-transport) method params &key timeout id)
  (unless sse-protocol:*sse-backend*
    (error 'rpc-protocol:rpc-error
           :message "*sse-backend* is nil — load sse-backend-http"
           :code rpc-protocol:+internal-error+))
  (let* ((id (or id (incf (transport-next-id transport))))
         (url (or (transport-url transport)
                  (error 'rpc-protocol:rpc-error
                         :message "sse RPC transport has no :url"
                         :code rpc-protocol:+internal-error+)))
         (conn (apply #'sse-protocol:open-sse url
                      :method :post
                      :content (rpc-protocol:encode-request method params :id id)
                      :headers '(("content-type" . "application/json"))
                      (when timeout (list :timeout timeout)))))
    (unwind-protect
         (let ((ev (sse-protocol:read-sse-event conn)))
           (unless ev
             (error 'rpc-protocol:rpc-error
                    :message "SSE RPC stream ended before a response"
                    :code rpc-protocol:+internal-error+))
           (%raise-rpc (rpc-protocol:decode-message (sse-protocol:sse-event-data ev))))
      (sse-protocol:close-sse conn))))

(defmethod rpc-protocol:backend-rpc-notify
    ((transport sse-rpc-transport) method params)
  (unless sse-protocol:*sse-backend*
    (error 'rpc-protocol:rpc-error
           :message "*sse-backend* is nil — load sse-backend-http"
           :code rpc-protocol:+internal-error+))
  (let ((conn (sse-protocol:open-sse
               (or (transport-url transport)
                   (error 'rpc-protocol:rpc-error
                          :message "sse RPC transport has no :url"
                          :code rpc-protocol:+internal-error+))
               :method :post
               :content (rpc-protocol:encode-notification method params)
               :headers '(("content-type" . "application/json")))))
    (sse-protocol:close-sse conn)
    t))

(defmethod rpc-protocol:backend-rpc-serve
    ((transport sse-rpc-transport) handler &key (host "127.0.0.1") (port 8080)
                                             (path "/"))
  (unless (find-package :sse-backend-clack)
    (asdf:load-system "sse-backend-clack"))
  (funcall (find-symbol "USE-CLACK-SSE-BACKEND" :sse-backend-clack))
  (sse-protocol:serve-sse
   (lambda (env)
     (let ((wire (%dispatch-wire handler (slurp-env-body env))))
       (list (sse-protocol:make-sse-event :event "message" :data wire))))
   :host host :port port :path path))

(use-sse-rpc-transport)
