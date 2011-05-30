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


(define-macro (with-color color . code)
  (cond (color
	 `(let ((original-color (get-current-color))
		(result #f))
	    (apply set-current-color ,color)
	    (set! result (begin ,@code))
	    (apply set-current-color original-color)
	    result))
	(else `(begin ,@code))))

(define-macro (progn-textures . code)
  `(let (values)
     (init-video-mode)
     (glEnable GL_TEXTURE_2D)
     (set! values (multiple-value-list (begin ,@code)))
     (glDisable GL_TEXTURE_2D)
     (apply values values)))

(define (draw . vertexes)
  (begin-draw (length vertexes))
  (draw-vertexes vertexes)
  (glEnd))

(define (begin-draw number-of-points)
  (cond ((= number-of-points 3) (glBegin GL_TRIANGLES))
	((= number-of-points 4) (glBegin GL_QUADS))))

(define (draw-vertexes vertexes)
  (cond ((not (null? vertexes))
	 (draw-vertex (car vertexes))
	 (draw-vertexes (cdr vertexes)))))

(define* (draw-vertex vertex #:key texture-coord)
  (cond ((list? (car vertex))
	 (with-color (car vertex)
		     (apply simple-draw-vertex (cadr vertex))))
	(else
	 (cond (texture-coord (apply glTexCoord2f texture-coord)))
	 (apply simple-draw-vertex vertex))))

(define* (simple-draw-vertex x y #:optional (z 0))
  (cond ((3d-mode?) (glVertex3f x y z))
	(else (glVertex2f x y))))

(define (load-image-for-texture filename)
  (init-video-mode)
  (let ((image (IMG_Load filename)))
    (cond (image
	   (let* ((width (surface-w image)) (height (surface-h image))
		  (power-2 (nearest-power-of-two (min width height)))
		  (resized-image #f))
	     (cond ((and (= width power-2) (= height power-2)) (values image width height))
		   (else (set! resized-image (resize-surface image power-2 power-2))
			 (if resized-image (values resized-image width height)))))))))

(define (resize-surface surface width height)
  (let ((old-width (surface-w surface)) (old-height (surface-h surface)))
    (cond ((and (= width old-width) (= height old-height)) surface)
	  (else (let ((zoomx (/ (+ width 0.5) old-width)) (zoomy (/ (+ height 0.5) old-height)))
	       (zoomSurface surface zoomx zoomy 0))))))

(define* (load-texture filename #:key (min-filter GL_LINEAR) (mag-filter GL_LINEAR))
  (progn-textures
   (receive
    (image real-w real-h) (load-image-for-texture filename)
    (cond (image
	   (let ((width (get-surface-width image)) (height (get-surface-height image))
		 (byteorder (if (= (SDL_ByteOrder) SDL_LIL_ENDIAN)
				(if (= (surface-format-BytesPerPixel image) 3) GL_BGR GL_BGRA)
				(if (= (surface-format-BytesPerPixel image) 3) GL_RGB GL_RGBA)))
		 (texture (car (glGenTextures 1))))

	     (glBindTexture GL_TEXTURE_2D texture)
	     (glTexImage2D GL_TEXTURE_2D 0 3 width height 0 byteorder GL_UNSIGNED_BYTE (surface-pixels image))
	     (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER min-filter)
	     (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER mag-filter)
	     texture))))))

(define* (draw-image filename #:optional (zoom 1))
  (let ((texture (load-texture filename)))
    (cond (texture (draw-texture texture zoom)))))

(define* (draw-texture texture #:optional (zoom 1))
  (cond (texture
	 (let ((width (texture-w texture))
	       (height (texture-h texture)))
	   (draw-rectangle (* zoom width) (* zoom height) #:texture texture)))))

(define* (draw-quad v1 v2 v3 v4 #:key texture color)
  (cond (texture
	 (progn-textures
	  (glBindTexture GL_TEXTURE_2D texture)
	  (begin-draw 4)
	  (draw-vertex v1 #:texture-coord '(0 0))
	  (draw-vertex v2 #:texture-coord '(1 0))
	  (draw-vertex v3 #:texture-coord '(1 1))
	  (draw-vertex v4 #:texture-coord '(0 1))
	  (glEnd)))
	(color
	 (with-color color (draw v1 v2 v3 v4)))
	(else
	 (draw v1 v2 v3 v4))))

(define* (draw-rectangle width height #:key texture color)
  (draw-quad (list (- width) height 0)
	     (list width height 0)
	     (list width (- height) 0)
	     (list (- width) (- height) 0)
	     #:texture texture
	     #:color color))

(define* (draw-square #:key (size 1) texture color)
  (draw-rectangle size size #:texture texture #:color color))

(define* (draw-cube #:key (size 1)
		   texture texture-1 texture-2 texture-3 texture-4 texture-5 texture-6
		   color color-1 color-2 color-3 color-4 color-5 color-6)
  (let ((-size (- size)))
    (progn-textures
     (glNormal3f 0 0 1)
     (draw-quad (list -size size size) (list size size size) (list size -size size) (list -size -size size) #:texture (or texture-1 texture) #:color (or color-1 color))
     (glNormal3f 0 0 -1)
     (draw-quad (list -size -size -size) (list size -size -size) (list size size -size) (list -size size -size) #:texture (or texture-2 texture) #:color (or color-2 color))
     (glNormal3f 0 1 0)
     (draw-quad (list size size size) (list -size size size) (list -size size -size) (list size size -size) #:texture (or texture-3 texture) #:color (or color-3 color))
     (glNormal3f 0 -1 0)
     (draw-quad (list -size -size size) (list size -size size) (list size -size -size) (list -size -size -size) :texture (or texture-4 texture) #:color (or color-4 color))
     (glNormal3f 1 0 0)
     (draw-quad (list size -size -size) (list size -size size) (list size size size) (list size size -size) :texture (or texture-5 texture) #:color (or color-5 color))
     (glNormal3f -1 0 0)
     (draw-quad (list -size -size size) (list -size -size -size) (list -size size -size) (list -size size size) :texture (or texture-6 texture) #:color (or color-6 color)))))

(define* (add-light #:key light position ambient (id GL_LIGHT1) (turn-on t))
  (init-lighting)
  (and light (glLightfv id GL_DIFFUSE (first light) (second light) (third light) (fourth light)))
  (and light position (glLightfv GL_POSITION (first position) (second position) (third position) (fourth position)))
  (and ambient (glLightfv id GL_AMBIENT (first ambient) (second ambient) (third ambient) (fourth ambient)))
  (and turn-on (glEnable id))
  id)

(define* (translate x y #:optional (z 0))
  (glTranslatef x y z))

(define* (rotate #:rest rot)
  (cond ((3d-mode?) (apply 3d-rotate rot))
	(else (apply 2d-rotate rot))))

(define (3d-rotate xrot yrot zrot)
  (glRotatef xrot 1 0 0)
  (glRotatef yrot 0 1 0)
  (glRotatef zrot 0 0 1))

(define (2d-rotate rot)
  (glRotatef rot 0 0 1))

(define (to-origin)
  (glLoadIdentity)
  (cond ((3d-mode?) (camera-look))))

(define set-camera #f)
(define camera-look #f)

(let ((camera-eye '(0 0 0)) (camera-center '(0 0 -100)) (camera-up '(0 1 0)))
  (set! set-camera
	(lambda* (#:key eye center up)
	  (cond (eye (set! camera-eye eye)))
	  (cond (center (set! camera-center center)))
	  (cond (up (set! camera-up up)))))

  (set! camera-look
	(lambda ()
	  (apply gluLookAt (append camera-eye camera-center camera-up)))))