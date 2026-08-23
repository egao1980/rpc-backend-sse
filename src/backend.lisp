(in-package #:rpc-backend-sse)

(defclass sse-rpc-transport (rpc-protocol:rpc-transport) ())

(defun make-sse-rpc-transport ()
  (make-instance 'sse-rpc-transport))

(defun use-sse-rpc-transport ()
  (setf rpc-protocol:*rpc-transport* (make-sse-rpc-transport)))

(defmethod rpc-protocol:backend-rpc-call ((transport sse-rpc-transport) method params &key timeout id)
  (declare (ignore timeout id))
  (error 'rpc-protocol:rpc-error
         :message "rpc-backend-sse: backend-rpc-call not implemented"
         :code rpc-protocol:+internal-error+))

(defmethod rpc-protocol:backend-rpc-notify ((transport sse-rpc-transport) method params)
  (declare (ignore method params))
  (error 'rpc-protocol:rpc-error
         :message "rpc-backend-sse: backend-rpc-notify not implemented"
         :code rpc-protocol:+internal-error+))

(defmethod rpc-protocol:backend-rpc-serve ((transport sse-rpc-transport) handler &key)
  (declare (ignore handler))
  (error 'rpc-protocol:rpc-error
         :message "rpc-backend-sse: backend-rpc-serve not implemented"
         :code rpc-protocol:+internal-error+))
