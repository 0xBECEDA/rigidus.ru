(in-package #:rigidus)


;; 404

(defun page-404 (&optional (title "404 Not Found") (content "Страница не найдена"))
  (let* ((title "404 Not Found")
         (menu-memo (menu)))
    (restas:render-object
     (make-instance 'rigidus-render)
     (list title
           menu-memo
           (tpl:default
               (list :title title
                     :navpoints menu-memo
                     :content "Страница не найдена"))))))

(restas:define-route not-found-route ("*any")
  (restas:abort-route-handler
   (page-404)
   :return-code hunchentoot:+http-not-found+
   :content-type "text/html"))


;; main

(restas:define-route main ("/")
  (let* ((lines (iter (for line in-file (path "afor.txt") using #'read-line)
                     (collect line)))
         (line (nth (random (length lines))
                    lines)))
    (list "Программирование - как искусство"
          (menu)
          (tpl:main (list :title line
                          :links )))))


;; plan file pages

(defmacro def/route (name param &body body)
  `(progn
     (restas:define-route ,name ,param
       ,@body)
     (restas:define-route
         ,(intern (concatenate 'string (symbol-name name) "/"))
         ,(cons (concatenate 'string (car param) "/") (cdr param))
       ,@body)))


(def/route about ("about")
  (path "content/about.org"))

(def/route resources ("resources")
  (path "content/resources.org"))

(def/route faq ("faq")
  (path "content/faq.org"))

(def/route contacts ("contacts")
  (path "content/contacts.org"))


;; showing articles

(defun show-article-from-hash (strkey hash)
  (multiple-value-bind (article isset)
      (gethash strkey hash)
    (unless isset
      (restas:abort-route-handler
       (page-404)
       :return-code hunchentoot:+http-not-found+
       :content-type "text/html"))
      article))


(def/route articles ("articles")
  *cached-articles-page*)


(def/route aliens ("aliens")
  *cached-alien-page*)


(def/route article ("articles/:strkey")
  (show-article-from-hash strkey *articles*))

;; (def/route article-post-action ("articles/:strkey" :method :post)
;;   ;; (format nil "zzz: ~A" (hunchentoot:post-parameters*)))
;;   ;; acts
;;   (aif (hunchentoot:parameter "act")
;;        (cond ((string= it "comment-del")
;;               ;; ***TODO***: reqursive delete
;;               (format nil "~A"
;;                       (execute
;;                        (sql (:delete-from 'comment :where (:= 'id (parse-integer (hunchentoot:post-parameter "id"))))))))
;;              ((string= it "comment-add")
;;               ;; ***TODO***: escape strings, rebuild comments
;;               (let ((newmsg (make-dao 'comment
;;                                       :parent (parse-integer (hunchentoot:post-parameter "parent"))
;;                                       :msg (hunchentoot:post-parameter "msg")
;;                                       :key (string-upcase strkey)
;;                                       :id (incf-comment-id))))
;;                 (json:encode-json-alist-to-string
;;                  `((id    . ,(id newmsg))
;;                    (msg   . ,(msg newmsg))))))
;;              ((string= it "comment-expand")
;;               ;; (format nil "zzz: ~A" (hunchentoot:post-parameters*))
;;               ;; (format nil "iii: ~A"
;;               ;;         (parse-integer (hunchentoot:post-parameter "id")))
;;               (if (equal "0" (hunchentoot:post-parameter "id"))
;;                   (json:encode-json-to-string nil)
;;                   ;; else
;;                   (json:encode-json-to-string
;;                    (reverse
;;                     (cdr
;;                      (reqursive-comments-view
;;                       (get-comments (parse-integer (hunchentoot:post-parameter "id")))))))))
;;              ((string= it "comment-edit") "-edit")
;;              (t (error 'act-param-not-valid)))
;;        ;; else
;;        (error 'act-not-found-post-actions)))
  ;; (show-article-from-hash strkey *articles*))



(def/route alien ("alien/:strkey")
  (show-article-from-hash strkey *aliens*))


(restas:define-route onlisp ("onlisp/doku.php")
  (let* ((content (tpl:onlisp))
         (title "Перевод книги Пола Грэма \"On Lisp\"")
         (menu-memo (menu)))
    (restas:render-object
     *default-render-method*
     (list title
           menu-memo
           (tpl:default
               (list :title title
                     :navpoints menu-memo
                     :sections ""
                     :links ""
                     :content content))))))



(require 'bordeaux-threads)

(defparameter *serial-status* nil)
(defparameter *serial-lock*   (bordeaux-threads:make-lock "serial-lock"))

(defun serial-getter ()
  (tagbody
   re
     (bordeaux-threads:acquire-lock *serial-lock* t)
     (with-open-file (stream "/dev/ttyUSB0"
                             :direction :io
                             :if-exists :overwrite
                             :external-format :ascii)
       (setf *serial-status* (format nil "~C" (read-char stream))))
     (bordeaux-threads:release-lock *serial-lock*)
     (go re)))


(defparameter *serial-thread* (bordeaux-threads:make-thread #'serial-getter :name "serial-getter"))

(restas:define-route test ("test")
  (with-open-file (stream "/dev/ttyUSB0"
                          :direction :io
                          :if-exists :overwrite
                          :external-format :ascii)
    (format stream "9"))
  (sleep 1)
  (let ((tmp (parse-integer *serial-status*))
        (rs  nil))
    (if (equal 1 (logand tmp 1))
      (setf rs (append rs (list :red "checked")))
      (setf rs (append rs (list :darkred "checked"))))
    (if (equal 2 (logand tmp 2))
        (setf rs (append rs (list :lightgreen "checked")))
        (setf rs (append rs (list :green "checked"))))
    (let* ((content (tpl:controltbl rs))
           (title "Control Service")
           (menu-memo (menu)))
      (restas:render-object
       (make-instance 'rigidus-render)
       (list title
             menu-memo
             (tpl:default
                 (list :title title
                       :navpoints menu-memo
                       :content content)))))))

(restas:define-route test-post ("test" :method :post)
  (let ((rs 0))
    (when (string= (hunchentoot:post-parameter "red") "on")
      (setf rs (logior rs 1)))
    (when (string= (hunchentoot:post-parameter "green") "on")
      (setf rs (logior rs 2)))
    (with-open-file (stream "/dev/ttyUSB0"
                            :direction :io
                            :if-exists :overwrite
                            :external-format :ascii)
      (format stream "~A" rs))
    (hunchentoot:redirect "/test")))







;; submodules

(restas:mount-submodule -css- (#:restas.directory-publisher)
  (restas.directory-publisher:*baseurl* '("css"))
  (restas.directory-publisher:*directory* (path "css/")))

(restas:mount-submodule -js- (#:restas.directory-publisher)
  (restas.directory-publisher:*baseurl* '("js"))
  (restas.directory-publisher:*directory* (path "js/")))

(restas:mount-submodule -img- (#:restas.directory-publisher)
  (restas.directory-publisher:*baseurl* '("img"))
  (restas.directory-publisher:*directory* (path "img/")))

(restas:mount-submodule -resources- (#:restas.directory-publisher)
  (restas.directory-publisher:*baseurl* '("resources"))
  (restas.directory-publisher:*directory* (path "resources/")))
