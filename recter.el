;;; recter.el --- Extensions to rect.el

;; Author: Masahiro Hayashi <mhayashi1120@gmail.com>
;; Keywords: extensions, data, tools
;; URL: https://github.com/mhayashi1120/Emacs-recter
;; Emacs: GNU Emacs 22 or later
;; Version: 1.1.1
;; Package-Requires: ()

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; recter.el provides extensions to rect.el

;; ## Install:

;; Put this file into load-path'ed directory, and byte compile it if
;; desired. And put the following expression into your ~/.emacs.
;;
;;     (require 'recter)
;;     (define-key ctl-x-r-map "C" 'recter-copy-rectangle)
;;     (define-key ctl-x-r-map "N" 'recter-insert-number-rectangle)
;;     (define-key ctl-x-r-map "\M-c" 'recter-create-rectangle-by-regexp)
;;     (define-key ctl-x-r-map "A" 'recter-append-rectangle-to-eol)
;;     (define-key ctl-x-r-map "R" 'recter-kill-ring-to-rectangle)
;;     (define-key ctl-x-r-map "K" 'recter-rectangle-to-kill-ring)
;;     (define-key ctl-x-r-map "\M-l" 'recter-downcase-rectangle)
;;     (define-key ctl-x-r-map "\M-u" 'recter-upcase-rectangle)
;;     (define-key ctl-x-r-map "E" 'recter-copy-to-eol)
;;     (define-key ctl-x-r-map "\M-E" 'recter-kill-to-eol)

;; ```********** Emacs 22 or earlier **********```
;;
;;     (require 'recter)
;;     (global-set-key "\C-xrC" 'recter-copy-rectangle)
;;     (global-set-key "\C-xrN" 'recter-insert-number-rectangle)
;;     (global-set-key "\C-xr\M-c" 'recter-create-rectangle-by-regexp)
;;     (global-set-key "\C-xrA" 'recter-append-rectangle-to-eol)
;;     (global-set-key "\C-xrR" 'recter-kill-ring-to-rectangle)
;;     (global-set-key "\C-xrK" 'recter-rectangle-to-kill-ring)
;;     (global-set-key "\C-xr\M-l" 'recter-downcase-rectangle)
;;     (global-set-key "\C-xr\M-u" 'recter-upcase-rectangle)
;;     (global-set-key "\C-xrE" 'recter-copy-to-eol)
;;     (global-set-key "\C-xr\M-E" 'recter-kill-to-eol)

;;; Code:

(require 'rect)

(defvar current-prefix-arg)

;;;
;;; Internal function
;;;

(defun recter--just-a-format-p (fmt)
  (and
   (condition-case nil (format fmt 1) (error nil))
   ;; heuristic check ;-)
   (catch 'done
     (let ((i 0))
       (while (< i 3)
         (let* ((r (random))
                (fmttext (format fmt r))
                (dectext (number-to-string r))
                (hextext (format "%x" r))
                (octtext (format "%o" r))
                (case-fold-search t))
           (unless (or (string-match dectext fmttext)
                       (string-match hextext fmttext)
                       (string-match octtext fmttext))
             (throw 'done nil))
           (setq i (1+ i))))
       t))))

(defun recter--count-lines (start end)
  (let ((lines 0))
    (save-excursion
      (goto-char start)
      (while (and (<= (point) end)
                  (not (eobp)))
        (forward-line 1)
        (setq lines (1+ lines))))
    lines))

(defun recter-do-translate (start end translator)
  "TRANSLATOR is function accept one string argument and return string."
  (apply-on-rectangle
   (lambda (s e)
     (let* ((start (progn (move-to-column s) (point)))
	    (end (progn (move-to-column e) (point)))
	    (current (buffer-substring start end))
	    (new (funcall translator current)))
       (unless (string= current new)
	 (delete-region start end)
	 (insert new))))
   start end))

;;;
;;; UI
;;;

;;
;; Read minibuffer
;;

(defun recter-read-from-minibuffer (prompt must-match-regexp &optional default)
  "Check input string by MUST-MACH-REGEXP.
See `read-from-minibuffer'."
  (let (str)
    (while (null str)
      (setq str (read-from-minibuffer prompt default))
      (unless (string-match must-match-regexp str)
	(message "Invalid string!")
	(sit-for 0.5)
	(setq str nil)))
    str))

(defun recter-read-number (prompt default)
  (string-to-number (recter-read-from-minibuffer
		     prompt "\\`[-+]?[0-9]+\\'"
		     (number-to-string default))))

(defun recter-non-rectangle-to-rectangle (strings)
  (let ((max 0))
    (dolist (s strings)
      (let ((wid (string-width s)))
        (when (> wid max)
          (setq max wid))))
    (let ((fmt (concat "%-" (number-to-string max) "s")))
      (mapcar
       (lambda (s)
         (format fmt s))
       strings))))

(defun recter-read-regexp (prompt)
  (if (fboundp 'read-regexp)
      (read-regexp prompt)
    (read-from-minibuffer (concat prompt ": "))))

;;
;; message
;;

(defun recter-msg--after-kill ()
  (message "%s"
           (substitute-command-keys
	    (concat "Killed text converted to rectangle. "
		    "You can type \\[yank-rectangle] now."))))

;;
;; Internal function
;;

(defun recter--*-to-eol-region (start end &optional delete)
  (save-excursion
    ;; save end as marker
    (goto-char end)
    (setq end (point-marker))
    (goto-char start)
    (let ((start-col (current-column))
          (list '()))
      (while (and (<= (point) end)
                  (not (eobp)))
        (let ((s (buffer-substring (point) (line-end-position))))
          (when delete
            (delete-region (point) (line-end-position)))
          (setq list (cons s list)))
        (forward-line 1)
        (move-to-column start-col))
      (setq list (nreverse list))
      (setq killed-rectangle
            (recter-non-rectangle-to-rectangle list))))
  (recter-msg--after-kill))

;;;
;;; Interactive Command
;;;

;;;###autoload
(defun recter-rectangle-to-kill-ring ()
  "Killed rectangle to normal `kill-ring'.
After executing this command, you can type \\[yank]."
  (interactive)
  (with-temp-buffer
    (yank-rectangle)
    ;;avoid message
    (let (message-log-max)
      (message ""))
    (kill-new (buffer-string)))
  (message "%s"
           (substitute-command-keys
	    (concat "Killed rectangle converted to normal text. "
		    "You can type \\[yank] now."))))

;;;###autoload
(defun recter-kill-ring-to-rectangle (&optional succeeding)
  "Make rectangle from clipboard or `kill-ring'.
After executing this command, you can type \\[yank-rectangle]."
  (interactive
   (let (str)
     (when current-prefix-arg
       (setq str (read-from-minibuffer "Succeeding string to killed: ")))
     (list str)))
  (let ((tab tab-width))
    (with-temp-buffer
      ;; restore
      (setq tab-width tab)
      (insert (current-kill 0))
      (goto-char (point-min))
      (let (str list)
	(while (not (eobp))
	  (setq str (buffer-substring (line-beginning-position) (line-end-position)))
	  (when succeeding
	    (setq str (concat str succeeding)))
	  (setq list (cons str list))
	  (forward-line 1))
        (setq list (nreverse list))
	(setq killed-rectangle
	      (recter-non-rectangle-to-rectangle list)))))
  (recter-msg--after-kill))

;;;###autoload
(defun recter-append-rectangle-to-eol (&optional preceeding)
  "Append killed rectangle to end-of-line sequentially."
  (interactive
   (let (str)
     (when current-prefix-arg
       (setq str (read-from-minibuffer "Preceeding string to append: ")))
     (list str)))
  (unless preceeding
    (setq preceeding ""))
  (save-excursion
    (mapc
     (lambda (x)
       (goto-char (line-end-position))
       (insert preceeding)
       (insert x)
       (forward-line 1)
       ;; reach to eob and no last newline
       (when (and (eobp)
                  (not (bolp)))
         (newline)))
     killed-rectangle)))

;;;###autoload
(defun recter-copy-rectangle (start end)
  "Copy rectangle area."
  (interactive "r")
  (deactivate-mark)
  (setq killed-rectangle (extract-rectangle start end))
  (recter-msg--after-kill))

;;;###autoload
(defun recter-insert-number-rectangle (begin end number-fmt &optional step start-from)
  "Insert incremental number into each left edges of rectangle's line.

BEGIN END is rectangle region to insert numbers.
 Which is allowed BEGIN over END. In this case, inserted descendant numbers.
 e.g
   1. In dired buffer type `\\<dired-mode-map>\\[dired-sort-toggle-or-edit]' \
to sort by modified date descendantly.
   2. Type \\<dired-mode-map>\\[wdired-change-to-wdired-mode] to use `wdired'.
   3. Activate region from old file to new file.
   4. Do this command to make sequential file name ordered by modified date.

NUMBER-FMT may indicate start number and inserted format.
  \"1\"   => [\"1\" \"2\" \"3\" ...]
  \"001\" => [\"001\" \"002\" \"003\" ...]
  \" 1\"  => [\" 1\" \" 2\" \" 3\" ...]
  \" 5\"  => [\" 5\" \" 6\" \" 7\" ...]

This format indication more familiar than `rectangle-number-lines'
implementation, I think :-)

On the other hand NUMBER-FMT accept \"%d\", \"%o\", \"%x\" like format too.

  \"%03d\" => [\"001\" \"002\" \"003\" ...]
  \"%3d\" => [\"  1\" \"  2\" \"  3\" ...]
  \"file-%03d\" => [\"file-001\" \"file-002\" \"file-003\" ...]
  \"%03x\" => [\"001\" ... \"00a\" \"00b\" ...]

START-FROM indicate number to start, more prior than NUMBER-FMT.
STEP is incremental count. Default is 1.
"
  (interactive
   (progn
     (unless mark-active
       (signal 'mark-inactive nil))
     (let ((beg (region-beginning))
	   (fin (region-end))
	   fmt step start-num)
       ;; swap start end if mark move backward to beginning-of-buffer
       (when (eq beg (point))
         (let ((tmp beg))
           (setq beg fin
                 fin tmp)))
       (setq fmt (recter-read-from-minibuffer
                  "Start number or format: "
                  ;; allow all
                  ".+"))
       (when current-prefix-arg
	 (setq step (recter-read-number "Step: " 1))
         (when (recter--just-a-format-p fmt)
           (setq start-num (recter-read-number "Start from: " 1))))
       (deactivate-mark)
       (list beg fin fmt step start-num))))
  (let* ((min (min begin end))
         (max (max begin end))
         (lines (recter--count-lines min max))
         (l 0)
         fmt start rect-lst)
    (cond
     ((recter--just-a-format-p number-fmt)
      (setq fmt number-fmt)
      ;; default is start from 1
      (setq start (or start-from 1)))
     ((string-match "\\([0 ]\\)*\\([0-9]+\\)" number-fmt)
      (let* ((before (substring number-fmt 0 (match-beginning 0)))
             (after (substring number-fmt (match-end 0)))
             (start-text (match-string 2 number-fmt))
             (padchar (match-string 1 number-fmt))
             (fmt-body (match-string 0 number-fmt))
             (fmtlen (number-to-string (length fmt-body))))
        (setq fmt (concat before "%" padchar fmtlen "d" after))
        (setq start (string-to-number start-text))))
     (t (error "Invalid number format %s" fmt)))
    (setq step (or step 1))
    (save-excursion
      (delete-rectangle min max)
      ;; computing list of insertings
      (while (< l lines)
        (setq rect-lst (cons (format fmt start) rect-lst))
        (setq start (+ step start)
              l (1+ l)))
      (when (>= end begin)
        (setq rect-lst (nreverse rect-lst)))
      (goto-char min)
      (insert-rectangle rect-lst))))

;;;###autoload
(defun recter-create-rectangle-by-regexp (start end regexp)
  "Capture string matching to REGEXP.
Only effect to region if region is activated.
"
  (interactive
   (let* ((beg (if mark-active (region-beginning) (point-min)))
	  (end (if mark-active (region-end) (point-max)))
	  (regexp (recter-read-regexp "Regexp")))
     (list beg end regexp)))
  (let (str list)
    (save-excursion
      (save-restriction
	(narrow-to-region start end)
	(goto-char (point-min))
	(while (re-search-forward regexp nil t)
	  (setq str (match-string 0))
	  (setq list (cons str list)))))
    (setq list (nreverse list))
    ;; fill by space
    (setq killed-rectangle
	  (recter-non-rectangle-to-rectangle list))
    (recter-msg--after-kill)))

;;;###autoload
(defun recter-upcase-rectangle (start end)
  "Upcase rectangle"
  (interactive "*r")
  (recter-do-translate start end 'upcase))

;;;###autoload
(defun recter-downcase-rectangle (start end)
  "Downcase rectangle"
  (interactive "*r")
  (recter-do-translate start end 'downcase))

;;;###autoload
(defun recter-kill-to-eol (start end)
  "Kill rectangle START column to end of line in rectangle.
END is indicated as last line of rectangle.
This function is useful if last column trailing space was truncated."
  (interactive "r")
  (recter--*-to-eol-region start end t))

;;;###autoload
(defun recter-copy-to-eol (start end)
  "Copy rectangle START column to end of line in rectangle.
END is indicated as last line of rectangle.
This function is useful if last column trailing space was truncated."
  (interactive "r")
  (recter--*-to-eol-region start end))

;; for ELPA
;;;###autoload(define-key ctl-x-r-map "C" 'recter-copy-rectangle)
;;;###autoload(define-key ctl-x-r-map "N" 'recter-insert-number-rectangle)
;;;###autoload(define-key ctl-x-r-map "\M-c" 'recter-create-rectangle-by-regexp)
;;;###autoload(define-key ctl-x-r-map "A" 'recter-append-rectangle-to-eol)
;;;###autoload(define-key ctl-x-r-map "R" 'recter-kill-ring-to-rectangle)
;;;###autoload(define-key ctl-x-r-map "K" 'recter-rectangle-to-kill-ring)
;;;###autoload(define-key ctl-x-r-map "\M-l" 'recter-downcase-rectangle)
;;;###autoload(define-key ctl-x-r-map "\M-u" 'recter-upcase-rectangle)
;;;###autoload(define-key ctl-x-r-map "E" 'recter-copy-to-eol)
;;;###autoload(define-key ctl-x-r-map "\M-E" 'recter-kill-to-eol)

(provide 'recter)

;;; recter.el ends here
