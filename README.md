recter.el
========

recter.el provides extensions to rect.el

## Install:

Put this file into load-path'ed directory, and byte compile it if
desired. And put the following expression into your ~/.emacs.

    (require 'recter)
    (define-key ctl-x-r-map "C" 'recter-copy-rectangle)
    (define-key ctl-x-r-map "N" 'recter-insert-number-rectangle)
    (define-key ctl-x-r-map "\M-c" 'recter-create-rectangle-by-regexp)
    (define-key ctl-x-r-map "A" 'recter-append-rectangle-to-eol)
    (define-key ctl-x-r-map "R" 'recter-kill-ring-to-rectangle)
    (define-key ctl-x-r-map "K" 'recter-rectangle-to-kill-ring)
    (define-key ctl-x-r-map "\M-l" 'recter-downcase-rectangle)
    (define-key ctl-x-r-map "\M-u" 'recter-upcase-rectangle)

```********** Emacs 22 or earlier **********```

    (require 'recter)
    (global-set-key "\C-xrC" 'recter-copy-rectangle)
    (global-set-key "\C-xrN" 'recter-insert-number-rectangle)
    (global-set-key "\C-xr\M-c" 'recter-create-rectangle-by-regexp)
    (global-set-key "\C-xrA" 'recter-append-rectangle-to-eol)
    (global-set-key "\C-xrR" 'recter-kill-ring-to-rectangle)
    (global-set-key "\C-xrK" 'recter-rectangle-to-kill-ring)
    (global-set-key "\C-xr\M-l" 'recter-downcase-rectangle)
    (global-set-key "\C-xr\M-u" 'recter-upcase-rectangle)
