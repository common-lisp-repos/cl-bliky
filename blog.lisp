(in-package :cl-user)
(defpackage :blog-cl)
(require :hunchentoot)
(require 'html-template)
(require :elephant)
(use-package :elephant)

(defconstant MONTHS     '("xx" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
(defconstant DAYS         '("Mon" "Tues" "Wed" "Thu" "Fri" "Sat" "Sun"))
(defconstant TIMEZONE     '("1" "2" "3" "4" "5" "Est" "6") )
(defconstant DEFAULT-PORT 8050)

(defvar *blog-store-location* (not t))
(defvar *bliky-server*        (not t))

;;blog classes
(defmacro post()      `'post) 
(defmacro about()     `'about)
(defmacro code()      `'code)
(defmacro sidebar()   `'sidebar)


(defmacro <title>() `"<title>")
(defmacro <split>() `"<split>")


(defmacro sandbox-repo-qs() `"sandbox-repo")
(defmacro main-repo-qs()    `"main-repo")


(setf (hunchentoot:log-file) "/tmp/error.file")



(defun fmt-timestamp(st)
  (multiple-value-bind 
	(second minute hour day month year dow dst-p tz)
      (decode-universal-time st)
    (declare (ignore dst-p))
    (format nil "~&~A ~A ~A ~A:~A:~A ~A ~A"
	    (nth dow DAYS)
	    (nth month MONTHS) 
	    day
	    hour 
	    minute 
	    second
	    (nth tz TIMEZONE)
	    year)))


(defpclass blog-post ()
  ((title :initarg :title
		   :accessor title)
   (intro :initarg :intro
		   :accessor intro)
   (body  :initarg  :body
		    :accessor body)
   (timestamp :initarg  :timestamp
	      :accessor timestamp
	      :initform (get-universal-time)
	      :index t)
   (gc-bit    :accessor gc-bit
	      :index t
              :initform (not t))
   (type-bit  :initarg :type-bit
              :accessor type-bit
	      :index t)
   (url-part  :initarg :url-part
	      :accessor url-part
	      :initform nil
	      :index t)))

(defmethod print-object ((u blog-post) stream)
  "specialize print object blog post"
  (format stream "~&blog-post : [title = ~A] [url-part = ~A][time=~A][gc=~A]~%[type=~A]~%[~A]~%[~A]~% "
	  (if (slot-boundp u 'title) 
	      (title u) 
	    "(blog-post not set)")
	  (if (slot-boundp u 'url-part)
	      (url-part u)
	    "(url-part not specified")
	  (if (slot-boundp u 'timestamp)
	      (timestamp u)
	    "(timestamp not set)")
	  (if (slot-boundp u 'gc-bit)
	      (gc-bit u)
	    "(gc not set)")
	  (if (slot-boundp u 'type-bit)
	      (type-bit u)
	    "(type bit not set)")
	  (if (slot-boundp u 'intro)
	      (intro u)
	    "(intro not set)")
	  (if (slot-boundp u 'body)
	      (body u)
	    "(body not set)")))

;;--------------settings-----------------

(defun blog-store-location()
  (if *blog-store-location*
      *blog-store-location*
      (let ((home (sb-posix:getenv "HOME")))
	(format nil "~A/store/blogs/" home))))

(defun get-settings()
  (let ((eb (get-from-root 'blog-settings)))
    (if eb
	eb
	(progn
	  (add-to-root 'blog-settings (make-btree))
	  (get-from-root 'blog-settings)))))

(defun set-bliky-setting(k v)
  (setf (get-value k (get-settings)) v))

(defun get-bliky-setting(k)
  (get-value k (get-settings)))


(defun set-bliky-port(port)
  (set-bliky-setting 'bliky-port port))

(defun get-bliky-port()
  (let ((val (get-bliky-setting 'bliky-port)))
    (if val
	val
	(set-bliky-port DEFAULT-PORT))))

(defun set-blog-title(title)
  (set-bliky-setting 'blog-title title))

(defun get-blog-title()
  (let ((val (get-bliky-setting 'blog-title)))
    (if val
	val
	(set-blog-title "blog title not set"))))

(defun set-contact-info(co)
  (set-bliky-setting 'contact-info co))

(defun get-contact-info()
  (let ((val (get-bliky-setting 'contact-info)))
    (if val
	val
	(set-contact-info "contact info not set"))))

;;---------------path name code-----------------------------------------
(defun set-bliky-pathname(path name)
  ;; nil is used to signal 'not set
  (if path
      (set-bliky-setting name (make-pathname :directory path))
      (set-bliky-setting name path))) 

(defun get-bliky-pathname(name default-path)
  ;; side effect : set path if not found to whatever
  ;; default-path generates.
  (let ((val (get-bliky-setting name)))
    (if val
	val
	(let ((path (funcall default-path)))
	  (set-bliky-pathname path name)))))


;----------------------------------
(defun set-template-pathname(p)
  (set-bliky-pathname p 'template-pathname))
  

(defun get-template-pathname()
  (labels ((df-path()
	     (let ((home (sb-posix:getenv "HOME")))
	       (format nil "~A/cl-bliky" home))))
    (get-bliky-pathname 'template-pathname #'df-path)))

(defun set-idiot-location(p)
  (set-bliky-pathname p 'idiot-location))

(defun get-idiot-location()
  (get-bliky-pathname 'idiot-location (lambda()"/tmp/idiot")))

;;--
(defun set-repo-pathname(p)
  (set-bliky-pathname p 'repo-pathname))

(defun get-repo-pathname()
  (labels ((df-path()
	     (let ((home (sb-posix:getenv "HOME"))
		   (user (sb-posix:getenv "USER")))	     
	       (format nil "~A/~A.github.com" home user))))
    (get-bliky-pathname 'repo-pathname #'df-path)))

;;--
(defun set-sandbox-pathname(p)
  (set-bliky-pathname p 'sandbox-pathname))

  
(defun get-sandbox-pathname()
  (labels ((df-path()
	     (let ((home (sb-posix:getenv "HOME"))
		   (user (sb-posix:getenv "USER")))	     
	       (format nil "~A/~A.sandbox.github.com" home user))))
    (get-bliky-pathname 'sandbox-pathname #'df-path)))

;;-----------------------------------------------------------------------

(defun set-mainstore?(v)
  (set-bliky-setting 'is_main_store v))
	 
(defun get-mainstore?()
  (if (get-bliky-setting 'is_main_store)
      t
      (not t)))

(defun blog-title()
  (get-blog-title))

(defun contact-info()
  (get-contact-info))


;;-----------git-repo-managment code-----------


(defun switch-to-repo(repo-path)
  (sb-posix:chdir repo-path))

(defun switch-to-default-path()
  (sb-posix:chdir *default-pathname-defaults*))

(defun string-to-list2(s sep)
  (let ((l ())
	(str (string-trim '(#\Space) s)))
    (do ((pos  (position sep str)
	       (position sep str)))
	((or (null pos) (eql 0 pos)))
      (push (string-left-trim '(#\Space) (subseq str 0 pos)) l)
      (setf str (string-left-trim '(#\Space) (subseq str (+ pos 1) ))))
    (nreverse l)))

(defun string-to-list(s)
  (let ((l ())
	(str (string-trim '(#\Space) s)))
    (do ((pos  (position #\Space str)
	       (position #\Space str)))
	((or (null pos) (eql 0 pos)))
      (push (string-left-trim '(#\Space) (subseq str 0 pos)) l)
      (setf str (string-left-trim '(#\Space) (subseq str pos ))))
    (push str l)
    (nreverse l)))

(defun run-cmd(cmd &optional args )
  (let ((str (make-string 0)))
    (labels ((set-args (args) 
	       (cond ((null args) nil)
		     ((listp args) args)
		     ((stringp args) (string-to-list args))
		     (t            nil))))
      (let* ((data (process-output (sb-ext:run-program cmd (set-args args)
						       :input :stream :output :stream :search t))))
	     
	(do ((line (read-line data nil 'eof)
		   (read-line data nil 'eof)))
	    ((eql line 'eof))
	  (setf str (concatenate 'string str line "|")) )))
    str))

(defun run-git(&optional args )
  (run-cmd "git" args))
	 
(defun find-deleted-files()
  (let* ((status (run-git "status"))
	 (lst ()))
    (do* ((pos  (search "deleted:" status)
		(search "deleted:" status)))
	 ((null pos))
      (let ((peek (search "|" (subseq status pos))))
	(push (string-trim '(#\Space) (subseq status (+ pos (length "deleted:")) (+ peek pos))) lst)
	(setf status (subseq status (+ peek pos)))))
    (nreverse lst)))

(defun git-rm-discarded-posts()
    (dolist (f (find-deleted-files) )
      (run-git (list "rm" f)))) 

(defun git-commit()
  (let* ((ts (substitute #\_ #\Space  (fmt-timestamp (get-universal-time))))
	 (msg  (concatenate 'string "commit  -m message_ok_" ts)))
    (run-git msg)))

(defun git-add-all-posts()
  (run-git "add *.html"))

(defun git-publish-branch()
  (run-git "checkout -b publish"))

(defun git-master-branch()
  (run-git "checkout master"))

(defun git-merge()
  (run-git "merge publish"))

(defun remove-files()
  (dolist (fn (string-to-list2 (run-cmd "ls") #\|))
    ;;(format t "~A~%" fn)
    (run-cmd "cp" (format nil "~A ~A" fn (get-idiot-location)))
    (run-cmd "rm" (format nil "~A" fn ))))

(defun git-publish()
  ;;
  ;; run ssh-add to add the pasword to the ssh agent.
  ;; this way you won't get challenged for a keyword..
  ;;
  (let* ((cmd "git")
	 (str (make-string 0))
	 (args  (list "push" "origin" "master"))
	 (proc  (sb-ext:run-program cmd args :wait nil :input :stream :output :stream :search t))
	 (data  (process-output proc)))
    (if (eql (process-status proc) :STOPPED)
	(progn
	  (process-kill proc -9)
	  (setf str (format nil 
			    "killed stopped process ~A ~A; add pwd to ssh agent; or run push manually" 
			    cmd args)))
	(do ((line (read-line data nil 'eof)
		   (read-line data nil 'eof)))
	    ((eql line 'eof))
	  ;;(format t "~A ~%" line)
	  (setf str (concatenate 'string str line "|"))))
    str))

;;-------------------

(defun blog-posts() 
  (or (get-from-root "blog-posts")
      (let ((blog-posts (make-pset)))
	(add-to-root "blog-posts" blog-posts)
	(blog-posts))))

(defun create-blog-post(title intro body type)
  (make-instance 'blog-post :title title :intro intro :body body :type-bit type))

(defun create-blog-post-template(type)
  (let* ((title "new blog post")
	 (intro "")
	 (body ""))
    (create-blog-post title intro body type)))

(defun create-about-post()
  (let* ((title "About")
	 (intro "")
	 (body ""))
    (create-blog-post title intro body (about))))

(defun create-code-post()
  (let* ((title "Code")
	 (intro "")
	 (body ""))
    (create-blog-post title intro body (code))))


(defun open-blog-store() 
  (let ((blog-store (list :BDB (blog-store-location) )))
    (if (null *store-controller*)  
	(open-store  blog-store )
	(print "store already opened"))))



(defun p-blogpost-active(blog-post)
  (cond ((not (gc-bit   blog-post))        t) 
	( t                           (not t))))

(defun p-blogpost-post(blog-post)
  (cond ((not (slot-boundp blog-post 'type-bit))        t)
	((eq  (type-bit blog-post) (post))              t)
	((eq  (type-bit blog-post) (not t))              t)
	( t                                             (not t))))

(defun p-blogpost-sidebar(blog-post)
  (cond ((eq  (type-bit blog-post) (sidebar))              t)
	( t                                             (not t))))

(defun p-blogpost(blog-post) 
  (and (p-blogpost-active blog-post) (p-blogpost-post blog-post)))

(defun p-sidebar(blog-post) 
  (and (p-blogpost-active blog-post) (p-blogpost-sidebar blog-post)))

(defun show-blogs()
  (map-class #'print 'blog-post))


(defun make-url-part(title)
  (string-downcase 
   (delete-if #'(lambda(x) (not (or (alphanumericp x) (char= #\- x))))
	      (substitute #\- #\Space title))))

(defmethod initialize-url-part  ((obj blog-post))
  (cond ((eq nil (url-part obj))
	 (setf (url-part obj) (make-url-part (title obj)))))) 

(defmethod initialize-instance :after ((obj blog-post) &key)
  (cond ((eq nil (url-part obj))
	 (setf (url-part obj) (make-url-part (title obj)))))) 



(defun style-css-path()
  (concatenate 'string (namestring (get-template-pathname)) "/style.css"))

;;from
;;www.emmett.ca/~sabetts/slurp.html
;;
(defun slurp-stream(stream)
  (let ((seq (make-string (file-length stream))))
    (read-sequence seq stream)
    seq))


(defun style-sheet()
  (with-open-file (stream (style-css-path) :direction :input)
    (slurp-stream stream)))


(defun discard-post-by-type(type)
  (let ((post (get-instance-by-value 'blog-post 'type-bit type)))
    (if post
	(setf (gc-bit post) t)
	nil)))

(defun get-live-blog-post(url-part)
  (let ((objs (get-instances-by-value 'blog-post 'url-part url-part)))
    (if objs
	(dolist (obj objs)
	  (if (p-blogpost-active obj)
	      (return obj)))
	nil)))

(defun get-blog-post(url-part) 
  (let ((obj (get-live-blog-post url-part)))
    (if obj
	obj
	(create-blog-post-template (post) ))))

(defun get-about-post()
  (let ((about-post (get-instance-by-value 'blog-post 'type-bit (about))))
    (if (null about-post)
	(create-about-post)
	about-post)))

(defun about-page() 
  (let ((obj (get-about-post)))
    (url-part obj)))

(defun get-code-post()
  (let ((code-post (get-instance-by-value 'blog-post 'type-bit (code))))
    (if (null code-post)
	(create-code-post)
	code-post)))

(defun code-list()
  (let ((obj (get-code-post)))
    (intro obj)))

(defun template-path(tmpl)
  (make-pathname :directory (namestring (get-template-pathname) )  :name tmpl))



(defun use-static-template(blog-post)
  (list :timestamp (fmt-timestamp (timestamp blog-post))
	:title (title blog-post)
	:url-part (url-part blog-post)
	:intro (intro blog-post)))

(defun use-edit-template(blog-post)
  (cons :edit_part (cons t (use-static-template blog-post))))


(defun collect-posts(tlf)
  (loop for blog-post in (nreverse 
			  (get-instances-by-range 'blog-post 
						  'timestamp nil nil))
     if (p-blogpost blog-post )
     collect (funcall tlf blog-post)))

(defun collect-sidebars(tlf)
  ;; note that this is oldest-firts order
  (loop for blog-post in (get-instances-by-range 'blog-post 
						 'timestamp nil nil)
     if (p-sidebar blog-post )
     collect (funcall tlf blog-post)))
  
(defun generate-index-page(tlf &key create)
  (with-output-to-string (stream)
    (let ((html-template:*string-modifier* #'identity))
      (html-template:fill-and-print-template
       (template-path "index.tmpl")
       (list :style-sheet (style-sheet)
	     (if create :edit_part) (if create t) 
	     :blog-title (blog-title)
	     :sandbox-repo-qs  (sandbox-repo-qs)
	     :main-repo-qs     (main-repo-qs)
	     :contact-info     (contact-info)
	     :about            (about-page)
	     :code             (code-list)
	     :code_url         (url-part (get-instance-by-value 'blog-post 'type-bit (code)))
	     :sidebars         (collect-sidebars tlf)
	     :blog-posts       (collect-posts    tlf))
	     :stream stream))))


(defun generate-editable-index-page()
  (generate-index-page #'use-edit-template :create t))

(defun generate-blog-post-page(tmpl url-part)
    (with-output-to-string (stream)
			   (let ((blog-post (get-live-blog-post url-part))
				 (html-template:*string-modifier* #'identity))
			     (if blog-post
				 (html-template:fill-and-print-template
				  tmpl
				  (list :style-sheet (style-sheet)
					:blog-title (blog-title)
					:title (title blog-post)
					:url_part url-part
					:timestamp (fmt-timestamp (timestamp blog-post))
					:intro (intro blog-post) 
					:body (body blog-post))
				  :stream stream)))))

;;(defun generate-blog-post-page(tmpl)
;;  (let ((up 
;;    (generate-blog-post-page-alt up tmpl)))

(defun view-blog-post-page()
  (generate-blog-post-page (template-path "post.tmpl") (hunchentoot:query-string)))


(defun save-blog-post() 
  (let ((blog-post (get-live-blog-post (hunchentoot:query-string))))
    (setf (title    blog-post) (hunchentoot:post-parameter "title"))
    (setf (intro    blog-post) (hunchentoot:post-parameter "intro"))
    (setf (body     blog-post) (hunchentoot:post-parameter "body"))
    (setf (url-part blog-post) (make-url-part (title blog-post)))
    (hunchentoot:redirect "/" )))

(defun split-sequence(seq tkw kw)
  (handler-case
      (let* ((ltkw   (length tkw))
	     (lkw    (length kw))
	     (tkwpos (search tkw seq))
	     (kwpos  (search kw  seq))
	     (title  (subseq seq 0 tkwpos))
	     (intro  (subseq seq (+ tkwpos ltkw 1) kwpos))
	     (body   (subseq seq (+ kwpos lkw 1))))
	(values title intro body))
    (error(c) 
      (declare (ignore c))
      (values "new blog post created from upload" "" seq))))
	 
(defun redirect-to-edit-page(blog-post)
  (hunchentoot:redirect (concatenate 'string "/edit/?"(url-part blog-post))))

(defun save-file()
  (labels ((read-file(params) 
	     (let ((fn (namestring(car params))))
	       (with-open-file (stream fn :direction :input)
		 (split-sequence (slurp-stream stream) (<title>) (<split>))))))
    (let ((blog-post (get-blog-post (hunchentoot:query-string))))
      (multiple-value-bind 
	    (title intro body) (read-file (hunchentoot:post-parameter "file"))
      (setf (title  blog-post) title) 
      (setf (intro  blog-post) intro) 
      (setf (body   blog-post) body)
      (setf (url-part blog-post) (make-url-part (title blog-post))))
      (redirect-to-edit-page blog-post))))


(defun discard-blog-post()
  (let ((blog-posts (get-instances-by-value 'blog-post 'url-part (hunchentoot:query-string))))
    (dolist (blog-post blog-posts)
      (setf (gc-bit blog-post) t))
    (hunchentoot:redirect "/" )))

(defun discard-all-blog-posts()
  (let ((blog-posts (get-instances-by-class 'blog-post)))
    (dolist (blog-post blog-posts)
      (setf (gc-bit blog-post) t))))
    
 
(defun undo-all-discards() 
  (let ((blog-posts (get-instances-by-value 'blog-post 'gc-bit t)))
    (dolist (blog-post blog-posts)
      (setf (gc-bit blog-post) (not t)))))

(defun drop-all-discards() 
  (let ((blog-posts (get-instances-by-value 'blog-post 'gc-bit t)))
    (drop-instances blog-posts)))

(defun str2type(str) 
  (cond ((eq    (not t) str)    (post))
        ((equal "post"  str)    (post))
	((equal "about" str)    (about))
	((equal "code"  str)    (code))
	((equal "sidebar" str) (sidebar))
	( t                    (post))))

(defun create-empty-blog-post(tmpl type-str)
  (let* ((bp (create-blog-post-template (str2type type-str)))
	 (up (url-part bp)))
    (generate-blog-post-page tmpl up)))

  
(defun create-blog-post-page()
  (cond ((eq (hunchentoot:request-method) :GET)  (create-empty-blog-post 
						  (template-path "post-edit.tmpl")
						  (hunchentoot:query-string)))
	((eq (hunchentoot:request-method) :POST) (save-blog-post))))

(defun edit-blog-post-page()
  (cond ((eq (hunchentoot:request-method) :GET)  (generate-blog-post-page 
						  (template-path "post-edit.tmpl")
						  (hunchentoot:query-string)))
	((eq (hunchentoot:request-method) :POST) (save-blog-post))))

(defun discard-blog-post-page()
  (cond ((eq (hunchentoot:request-method) :GET)  (discard-blog-post))
	((eq (hunchentoot:request-method) :POST) (discard-blog-post))))



(defun save-new-blog-post()
  (let* ((title (hunchentoot:post-parameter "title"))
	 (intro (hunchentoot:post-parameter "intro"))
	 (body  (hunchentoot:post-parameter "body"))
	 (blog-post (create-blog-post title intro body)))
    (redirect-to-edit-page blog-post)))

(defun undo-discards() 
  (undo-all-discards)
  (hunchentoot:redirect "/" ))

(defun drop-discards() 
  (drop-all-discards)
  (hunchentoot:redirect "/" ))

(defun push-pages-to-repo(repo-path)
  (labels ((publish-index-page()
	     (let ((fn (concatenate 'string repo-path "/index.html")))
	       (with-open-file (stream fn :direction :output :if-exists :supersede)
		 (format stream (generate-index-page #'use-static-template)))))
	   (url-parts()
	     (let ((lst))
	       (labels ((up(u) 
			  (if (slot-boundp u 'url-part)
			      (push (url-part u) lst))))
		 (map-class #'up 'blog-post))
	       (nreverse lst)))
	   (publish-other-pages()
	     (dolist (up (url-parts))
	       (let ((fn (concatenate 'string repo-path "/" up ".html")))
		 (with-open-file (stream fn :direction :output :if-exists :supersede)
		   (format stream (generate-blog-post-page (template-path "post.tmpl") up)))))))
    (publish-index-page)
    (publish-other-pages)))

(defun query-string-to-repo-path(qs)
  (cond ((equal qs (sandbox-repo-qs)) (get-sandbox-pathname))
	((equal qs (main-repo-qs))    (get-repo-pathname))
	( t                           (get-sandbox-pathname))))

(defun publish-pages()
  (let ((repo-pathname (query-string-to-repo-path (hunchentoot:query-string))))
    (switch-to-repo repo-pathname)
    (git-publish-branch)
    (remove-files)
    (push-pages-to-repo (namestring repo-pathname) )
    (git-add-all-posts)
    (when (get-mainstore?) (git-rm-discarded-posts))
    (git-commit)
    (git-master-branch)
    (git-merge)
    (git-publish)
    (switch-to-default-path))
    (hunchentoot:redirect "/"))

(setq hunchentoot:*dispatch-table* 
      (list (hunchentoot:create-regex-dispatcher "^/$"               'generate-editable-index-page)
	    (hunchentoot:create-regex-dispatcher "^/view/$"          'view-blog-post-page)
	    (hunchentoot:create-regex-dispatcher "^/edit/$"          'edit-blog-post-page)
	    (hunchentoot:create-regex-dispatcher "^/create/save-file"  'save-file)
	    (hunchentoot:create-regex-dispatcher "^/edit/save-file"  'save-file)
	    (hunchentoot:create-regex-dispatcher "^/discard/$"       'discard-blog-post-page)
	    (hunchentoot:create-regex-dispatcher "^/publish/$"       'publish-pages)
	    (hunchentoot:create-regex-dispatcher "^/undo-discards/$" 'undo-discards)
	    (hunchentoot:create-regex-dispatcher "^/drop-discards/$" 'drop-discards)
	    (hunchentoot:create-regex-dispatcher "^/create/$"        'create-blog-post-page)))


(defun start-server()
  (open-blog-store)
  (setf *bliky-server* (hunchentoot:start-server :port (get-bliky-port))))

(defun stop-server()
  (hunchentoot:stop-server *bliky-server*)
  (close-store))