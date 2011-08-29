(set-game-properties! #:title "Gacela Asteroids")

(define max-x (/ (assoc-ref (get-game-properties) 'width) 2))
(define min-x (- max-x))
(define max-y (/ (assoc-ref (get-game-properties) 'height) 2))
(define min-y (- max-y))

(define draw-asteroid
  (let ((asteroid (load-texture "Asteroid.png")))
    (lambda (a)
      (to-origin)
      (translate (assoc-ref a 'x) (assoc-ref a 'y))
      (rotate (assoc-ref a 'angle))
      (draw-texture asteroid))))

(define (move-asteroid a)
  (let* ((x (assoc-ref a 'x)) (y (assoc-ref a 'y))
	 (angle (assoc-ref a 'angle))
	 (vx (assoc-ref a 'vx)) (vy (assoc-ref a 'vy))
	 (nx (+ x vx)) (ny (+ y vy)))
    (cond ((> nx max-x) (set! vx -1))
	  ((< nx min-x) (set! vx 1)))
    (cond ((> ny max-y) (set! vy -1))
	  ((< ny min-y) (set! vy 1)))
    (set! angle (+ angle 1))
    `((x . ,(+ x vx)) (y . ,(+ y vy)) (angle . ,angle) (vx . ,vx) (vy . ,vy))))

(define draw-ship
  (let ((ship1 (load-texture "Ship1.png"))
	(ship2 (load-texture "Ship2.png")))
    (lambda (s)
      (to-origin)
      (translate (assoc-ref s 'x) (assoc-ref s 'y))
      (rotate (assoc-ref s 'angle))
      (let ((ship (if (assoc-ref s 'moving) ship2 ship1)))
	(draw-texture ship)))))

(define (move-ship s)
  (let ((x (assoc-ref s 'x)) (y (assoc-ref s 'y))
	(angle (assoc-ref s 'angle))
	(moving (assoc-ref s 'moving)))
    (cond ((key? 'left) (set! angle (+ angle 5)))
	  ((key? 'right) (set! angle (- angle 5))))
    (cond ((key? 'up)
	   (let ((r (degrees-to-radians (- angle))))
	     (set! x (+ x (* 4 (sin r))))
	     (set! y (+ y (* 4 (cos r)))))
	   (cond ((> x max-x) (set! x min-x))
		 ((< x min-x) (set! x max-x)))
	   (cond ((> y max-y) (set! y min-y))
		 ((< y min-y) (set! y max-y)))
	   (set! moving #t))
	  (else
	   (set! moving #f)))
    `((x . ,x) (y . ,y) (angle . ,angle) (moving . ,moving))))

(define (ship-shot s)
  (cond ((key-released? 'space)
	 #f)))

(define (make-asteroids n)
  (define (xy n r)
    (let ((n2 (- (random (* n 2)) n)))
      (cond ((and (< n2 r) (>= n2 0)) r)
	    ((and (> n2 (- r)) (< n2 0)) (- r))
	    (else n2))))

  (cond ((= n 0) '())
	(else
	 (cons `((x . ,(xy max-x 20)) (y . ,(xy max-y 20)) (angle . 0) (vx . 1) (vy . 1)) (make-asteroids (- n 1))))))

(let ((asteroids (make-asteroids 2))
      (ship '((x . 0) (y . 0) (angle . 0) (moving . #f)))
      (shots '())
  (run-game
   (set! asteroids (map move-asteroid asteroids))
   (set! ship (move-ship ship))
   (let ((shot (ship-shot ship)))
     (cond (shot
	    (set! shots (cons shot shots)))))
   (for-each draw-asteroid asteroids)
   (draw-ship ship)))
