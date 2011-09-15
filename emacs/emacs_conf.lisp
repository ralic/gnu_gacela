;;; Gacela configuration

(defun launch-gacela ()
  (interactive)
  (start-process "gacela" "gacela" "/home/jsancho/proyectos/gacela/trunk/src/gacela" "--dev"))

(defun send-to-gacela ()
  (interactive)
  (cond ((not (get-process "gacela"))
	 (launch-gacela)))
  (process-send-string "gacela" "(begin ")
  (cond ((use-region-p)
	 (process-send-region "gacela" (region-beginning) (region-end)))
	(t
	 (process-send-string "gacela" "(run-game) (clear-active-mobs)")
	 (process-send-region "gacela" (point-min-marker) (point-max-marker))))
  (process-send-string "gacela" "\n)\n"))

(define-key global-map [(ctrl x) (ctrl g)] 'send-to-gacela)

(define-key-after global-map [menu-bar tools gacela] (cons "Gacela" (make-sparse-keymap "hoot hoot")) 'games)
(define-key global-map [menu-bar tools gacela send] '("Send to Gacela" . send-to-gacela))
(define-key global-map [menu-bar tools gacela launch] '("Launch Gacela" . launch-gacela))

