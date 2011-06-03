;;; Gacela, a GNU Guile extension for fast games development
;;; Copyright (C) 2009 by Javier Sancho Fernandez <jsf at jsancho dot org>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.


(use-modules (srfi srfi-1))

;;; Actions for mobs

(define-macro (define-action action-def . code)
  (let ((name (car action-def)) (attr (cdr action-def)))
    `(define (,name mob-attr)
       (let ,(map attribute-definition attr)
	 ,@code
	 ,(cons 'list (map attribute-result attr))))))

(define (attribute-definition attribute)
  (let ((name (if (list? attribute) (car attribute) attribute))
	(value (if (list? attribute) (cadr attribute) #f)))
    `(,name (let ((v (assoc-ref mob-attr ',name))) (if v (cdr v) ,value)))))

(define (attribute-result attribute)
  (let ((name (if (list? attribute) (car attribute) attribute)))
    `(list ',name ,name)))


;;; Mob Factory

(define add-mob #f)
(define kill-mob #f)
(define kill-all-mobs #f)
(define refresh-active-mobs #f)
(define action-mobs #f)
(define render-mobs #f)

(let ((active-mobs '()) (mobs-to-add '()) (mobs-to-kill '())
  (set! add-mob
	(lambda (mob)
	  (pushnew mob mobs-to-add)))

  (set! kill-mob
	(lambda (mob)
	  (pushnew mob mobs-to-kill))

  (set! kill-all-mobs
	(lambda ()
	  (set! active-mobs '())
	  (set! mobs-to-add '())
	  (set! mobs-to-kill '())))

  (set! refresh-active-mobs
	(lambda ()
	  (define (add active to-add)
	    (cond ((null? to-add) active)
		  (else
		   (pushnew (car to-add) active)
		   (add active (cdr to-add)))))

	  (add active-mobs mobs-to-add)
	  (set! mobs-to-add '())
	  (set! active-mobs (reverse (lset-difference eq? active-mobs mobs-to-kill)))
	  (set! mobs-to-kill '())))

  (set! action-mobs
	(lambda ()
	  (map (lambda (m) (m #:action)) active-mobs)))

  (set! render-mobs
	(lambda ()
	  (map (lambda (m) (m #:render)) active-mobs))))


(define-macro (makemob name . methods)
  `(define* (,name . args)
     (let ((option (car args)))
       ,(lset-union eq?
	 `(case option
	    (:on (mob-on ',name))
	    (:off (mob-off ',name)))
	 (define (options m)
	   (let ((option (car m)) (body (cadr m)))
	     (cond ((null? m) '())
		   (else (cons (list option `(apply ,body (cdr args))) (options (cddr m)))))))
	 (options methods)))))

(define-macro (makemob name . methods)
  (define (options m)
    (cond ((null? m) '((else #f)))
	  (else
	   (let ((option (caar m)) (body (cadar m)))
	     (cons `((,option) (apply ,body (cdr args))) (options (cdr m)))))))
  (let ((m (options methods)))
    `(define (,name . args)
       (let ((option (car args)))
	 (case option
	   ((#:on) (mob-on ',name))
	   ((#:off) (mob-off ',name))
	   ,@m)))))


(define mob-on #f)
(define run-mobs #f)
(define mob-off #f)
(define refresh-running-mobs #f)
(define quit-all-mobs #f)

(let ((running-mobs '()) (mobs-to-add '()) (mobs-to-quit '()))
  (set! mob-on
	(lambda (mob)
	  (push mob mobs-to-add)))

  (set! run-mobs
	(lambda* (option #:key args function)
	  (define (run-mobs-rec mobs)
	    (cond ((null? mobs) #f)
		  (else
		   (cond (function (function)))
		   (catch #t (lambda () (apply (car mobs) (cons option args))) (lambda (key . args) #f))
		   (or #t (run-mobs-rec (cdr mobs))))))
	  (run-mobs-rec running-mobs)))

  (set! mob-off
	(lambda (mob)
	  (push mob mobs-to-quit)))

  (set! refresh-running-mobs
	(lambda ()
	  (do ((mob (pop mobs-to-add) (pop mobs-to-add))) ((null? mob))
	    (push mob running-mobs)
	    (catch #t (lambda () (mob #:init)) (lambda (key . args) #f)))
	  (set! running-mobs (reverse (lset-difference eq? running-mobs mobs-to-quit)))
	  (set! mobs-to-quit '())))

  (set! quit-all-mobs
	(lambda ()
	  (set! running-mobs '())
	  (set! mobs-to-add '())
	  (set! mobs-to-quit '()))))


(define (logic-mobs)
  (run-mobs #:logic))

(define (render-mobs)
  (run-mobs #:render #:function (lambda () (glLoadIdentity))))
