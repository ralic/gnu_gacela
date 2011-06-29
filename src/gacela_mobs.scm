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


;;; Mobs Factory

(define show-mob-hash #f)
(define hide-mob-hash #f)
(define get-active-mobs #f)
(define mobs-changed? #f)

(let ((active-mobs (make-hash-table)) (changed #f))
  (set! show-mob-hash
	(lambda (key mob)
	  (hash-set! active-mobs key mob)
	  (set! changed #t)))

  (set! hide-mob-hash
	(lambda (key)
	  (hash-remove! key)
	  (set! changed #t)))

  (set! get-active-mobs
	(lambda* (#:optional (refreshed #t))
	  (set! changed (not refreshed))
	  (hash-map->list (lambda (k v) v) active-mobs)))

  (set! mobs-changed?
	(lambda () changed)))


(define-macro (show-mob mob)
  `(show-mob-hash ',mob (lambda (option) (,mob option))))

(define-macro (hide-mob mob)
  `(hide-mob-hash ',mob))

(define (process-mobs mobs)
  (for-each (lambda (m) (m #:render)) mobs))


;;; Actions and looks for mobs

(define (get-attr list name default)
  (let ((value (assoc-ref list name)))
    (cond (value (car value))
	  (else default))))

(define (attr-def attr)
  (let ((name (car attr))
	(value (cadr attr)))
    `(,name (get-attr attributes ',name ',value))))

(define (attr-save attr)
  (let ((name (car attr)))
    `(set! attributes (assoc-set! attributes ',name (list ,name)))))

(define-macro (define-action action-head . code)
  (let ((name (car action-head)) (attr (cdr action-head)))
    `(define ,name
       (lambda-action ,attr ,@code))))

(define-macro (lambda-action attr . code)
  `(lambda (attributes)
     (let ,(map attr-def attr)
       ,@code
       ,(cons 'begin (map attr-save attr))
       attributes)))

(define-macro (lambda-look attr . look)
  (define (process-look look)
    (cond ((null? look) (values '() '()))
	  (else
	   (let ((line (car look)))
	     (receive (lines images) (process-look (cdr look))
		      (cond ((string? line)
			     (let ((var (gensym)))
			       (values (cons `(draw-texture ,var) lines)
				       (cons `(,var (load-texture ,line)) images))))
			    (else
			     (values (cons line lines)
				     images))))))))

  (receive (look-lines look-images) (process-look look)
	   `(let ,look-images
		(lambda (attributes)
		  (let ,(map attr-def attr)
		    (glPushMatrix)
		    ,@look-lines
		    (glPopMatrix))))))


;;; Making mobs

(define-macro (define-mob mob-head . look)
  (let ((name (car mob-head)) (attr (cdr mob-head)))
    `(define ,name
       (lambda-mob ,attr ,@look))))

(define-macro (lambda-mob attr . look)
  `(let ((mob #f))
     (set! mob
	   (let ((attr ',attr) (actions '()) (renders '()))
	     (lambda (option . params)
	       (case option
		 ((get-attr)
		  attr)
		 ((set-attr)
		  (if (not (null? params)) (set! attr (car params))))
		 ((get-actions)
		  actions)
		 ((set-actions)
		  (if (not (null? params)) (set! actions (car params))))
		 ((get-renders)
		  renders)
		 ((set-renders)
		  (if (not (null? params)) (set! renders (car params))))))))
     (cond ((not (null? ',look))
	    (mob 'set-renders
		 (list (cons
			'default-look
			(lambda-look () ,@look))))))
     mob))
