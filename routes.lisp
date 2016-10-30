;; [[file:doc.org::*Страница robots.txt][routes]]
(in-package #:rigidus)

(defclass rigidus-render () ())

(in-package #:rigidus)

(restas:define-route robots ("/robots.txt")
  (format nil "User-agent: *~%Disallow: "))

(in-package #:rigidus)

(defun page-404 (&optional (title "404 Not Found") (content "Страница не найдена"))
  (let* ((title "404 Not Found"))
    (tpl:root (list :headtitle title
                    :stat (tpl:stat)
                    :navpoints (menu)
                    :title title
                    :columns "<br/><br /><br/><br /><h2>404 Not Found</h2><br/><br /><br/><br />"))))

(restas:define-route not-found-route ("*any")
  (restas:abort-route-handler
   (page-404)
   :return-code hunchentoot:+http-not-found+
   :content-type "text/html"))

(in-package #:rigidus)

(restas:define-route main ("/")
  (let* ((lines (iter (for line in-file "afor.txt" using #'read-line) (collect line)))
         (line (nth (random (length lines)) lines))
         (data (list "Программирование - как искусство"
                     (menu)
                     (tpl:main (list :title line :links "")))))
    (destructuring-bind (headtitle navpoints content)
        data
      (tpl:root (list :headtitle headtitle
                      :stat (tpl:stat)
                      :navpoints navpoints
                      :title line
                      :columns
                      (tpl:main
                       (list
                        :articles
                        (tpl:mainposts
                         (list
                          :posts (sort (iter (for filename in (hash-table-keys *blogs*))
                                             (let* ((orgdata     (gethash filename *blogs*))
                                                    (directives  (orgdata-directives orgdata))
                                                    (date        (getf directives :date)))
                                               (when (null date)
                                                 (setf date "31.12.9999"))
                                               (setf (getf directives :timestamp)
                                                     (cl-ppcre:register-groups-bind ((#'parse-integer date month year))
                                                         ("(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4})" date)
                                                       (encode-universal-time  0 0 0 date month year 0)))
                                               (setf (getf directives :content)
                                                     (orgdata-content orgdata))
                                               (collect directives)))
                                       #'(lambda (a b)
                                           (> (getf a :timestamp)
                                              (getf b :timestamp)))))))))))))


(in-package #:rigidus)

(let ((h-articles (make-hash-table :test #'equal)))
   (def/route article ("articles/:strkey")
     (multiple-value-bind (article isset)
         (gethash strkey h-articles)
       (if isset
           (render article)
           (let* ((filename (format nil "content/articles/~A.org" strkey))
                  (truename (probe-file filename)))
             (if (null truename)
                 (page-404)
                 (let ((data (parse-org truename)))
                   (setf (orgdata-content data)
                         (process-directive-make-list-by-category data h-articles "subst"))
                   (destructuring-bind (headtitle navpoints)
                       (list "title" (menu))
                     (tpl:root (list :headtitle (getf (orgdata-directives data) :title)
                                     :stat (tpl:stat)
                                     :navpoints navpoints
                                     :title (getf (orgdata-directives data) :title)
                                     :columns (tpl:org (list :content (orgdata-content data)))))))))))))

;; TODO: blog

;; plan file pages

(def/route about ("about")
  (render #P"content/about.org"))

(def/route resources ("resources")
  (render #P"content/resources.org"))

(def/route faq ("faq")
  (render #P"content/faq.org"))

(def/route contacts ("contacts")
  (render #P"content/contacts.org"))

(def/route radio ("radio")
  (render #P"content/radio.org"))


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
  (render *cached-articles-page*))

(def/route aliens ("aliens")
  (render *cached-alien-page*))

(def/route alien ("alien/:strkey")
  (render (show-article-from-hash strkey *aliens*)))

;; TODO
;; (restas:define-route onlisp ("onlisp/doku.php")
;;   (let* ((content (tpl:onlisp))
;;          (title "Перевод книги Пола Грэма \"On Lisp\"")
;;          (menu-memo (menu)))
;;     (render
;;      (list title
;;            menu-memo
;;            (tpl:default
;;                (list :title title
;;                      :navpoints menu-memo
;;                      :sections ""
;;                      :links ""
;;                      :content content))))))

(require 'bordeaux-threads)

;; (defparameter *serial-status* nil)
;; (defparameter *serial-lock*   (bordeaux-threads:make-lock "serial-lock"))

;; (defun serial-getter ()
;;   (tagbody
;;    re
;;      (bordeaux-threads:acquire-lock *serial-lock* t)
;;      (with-open-file (stream "/dev/ttyACM0"
;;                              :direction :io
;;                              :if-exists :overwrite
;;                              :external-format :ascii)
;;        (setf *serial-status* (format nil "~C" (read-char stream))))
;;      (bordeaux-threads:release-lock *serial-lock*)
;;      (go re)))


;; (defparameter *serial-thread* (bordeaux-threads:make-thread #'serial-getter :name "serial-getter"))

;; ;; stty -F /dev/ttyACM0 cs8 9600 ignbrk -brkint -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke noflsh -ixon -crtscts raw

;; (restas:define-route test ("test")
;;   (with-open-file (stream "/dev/ttyACM0"
;;                           :direction :io
;;                           :if-exists :overwrite
;;                           :external-format :ascii)
;;     (format stream "9"))
;;   (sleep 1)
;;   (let ((tmp (parse-integer *serial-status*))
;;         (rs  nil))
;;     (if (equal 2 (logand tmp 2))
;;         (setf rs (append rs (list :red "checked")))
;;         (setf rs (append rs (list :darkred "checked"))))
;;     (if (equal 1 (logand tmp 1))
;;         (setf rs (append rs (list :lightgreen "checked")))
;;         (setf rs (append rs (list :green "checked"))))
;;     (let* ((content (tpl:controltbl rs))
;;            (title "Control Service")
;;            (menu-memo (menu)))
;;       (render (list title
;;                     menu-memo
;;                     (tpl:default
;;                         (list :title title
;;                               :navpoints menu-memo
;;                               :content content)))))))

;; (restas:define-route test-post ("test" :method :post)
;;   (let ((rs 0))
;;     (when (string= (hunchentoot:post-parameter "red") "on")
;;       (setf rs (logior rs 2)))
;;     (when (string= (hunchentoot:post-parameter "green") "on")
;;       (setf rs (logior rs 1)))
;;     (with-open-file (stream "/dev/ttyACM0"
;;                             :direction :io
;;                             :if-exists :overwrite
;;                             :external-format :ascii)
;;       (format stream "~A" rs))
;;     (hunchentoot:redirect "/test")))

;; submodules

(restas:mount-module -css- (#:restas.directory-publisher)
  (:url "/css/")
  (restas.directory-publisher:*directory* (merge-pathnames (make-pathname :directory '(:relative "repo/rigidus.ru/css")) (user-homedir-pathname))))

(restas:mount-module -font- (#:restas.directory-publisher)
  (:url "/font/")
  (restas.directory-publisher:*directory* (merge-pathnames (make-pathname :directory '(:relative "repo/rigidus.ru/font")) (user-homedir-pathname))))

(restas:mount-module -js- (#:restas.directory-publisher)
  (:url "/js/")
  (restas.directory-publisher:*directory* (merge-pathnames (make-pathname :directory '(:relative "repo/rigidus.ru/js"))  (user-homedir-pathname))))

(restas:mount-module -img- (#:restas.directory-publisher)
  (:url "/img/")
  (restas.directory-publisher:*directory* (merge-pathnames (make-pathname :directory '(:relative "repo/rigidus.ru/img")) (user-homedir-pathname))))

(restas:mount-module -resources- (#:restas.directory-publisher)
  (:url "/resources/")
  (restas.directory-publisher:*directory* (merge-pathnames (make-pathname :directory '(:relative "repo/rigidus.ru/resources")) (user-homedir-pathname)))
  (restas.directory-publisher:*autoindex* t))
;; routes ends here
