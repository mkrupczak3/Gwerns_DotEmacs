
(add-hook 'sh-mode-hook 'ansi-color-for-comint-mode-on)

;Enable narrowing of regions
(put 'narrow-to-region 'disabled nil)

;Allow a command to erase an entire buffer
(put 'erase-buffer 'disabled nil)

(put 'overwrite-mode 'disabled nil)

(put 'upcase-region 'disabled nil)

;Don't bother entering search and replace args if the buffer is read-only. Duh.
(defadvice query-replace-read-args (before barf-if-buffer-read-only activate)
  "Signal a `buffer-read-only' error if the current buffer is read-only."
  (barf-if-buffer-read-only))

;Answer y or n instead of yes or no at minibar prompts.
(defalias 'yes-or-no-p 'y-or-n-p)

;;Push the mouse out of the way when the cursor approaches.
(if window-system
    (progn
      (autoload 'avoid "avoid" "Avoid mouse and cursor being near each other")
      (eval-after-load 'avoid (mouse-avoidance-mode 'jump))))

;Make cursor stay in the same column when scrolling using pgup/dn.
;Previously pgup/dn clobbers column position, moving it to the
;beginning of the line.
;<http://www.dotemacs.de/dotfiles/ElijahDaniel.emacs.html>
(defadvice scroll-up (around ewd-scroll-up first act)
  "Keep cursor in the same column."
  (let ((col (current-column)))
    ad-do-it
    (move-to-column col)))
(defadvice scroll-down (around ewd-scroll-down first act)
  "Keep cursor in the same column."
  (let ((col (current-column)))
    ad-do-it
    (move-to-column col)))

;C-x k is a command I use often, but C-x C-k (an easy mistake) is
;bound to nothing! Set C-x C-k to same thing as C-x k.
(global-set-key "\C-x\C-k" 'kill-buffer)
(global-set-key "\C-x\C-c"
                '(lambda () (interactive)
                   (progn (if (and (boundp 'server-buffer-clients) server-buffer-clients)
                              (server-edit)
                            (save-buffers-kill-emacs t)))))

;IMPORTANT! This overrides a default binding!
;I don't use C-l much, and it makes more sense to me for it
;to kill backwards the line, like C-k kills forward the line.
;;define the function to kill the characters from the cursor
;;to the beginning of the current line
(defun backward-kill-line (arg)
  "Kill chars backward until encountering the end of a line."
  (interactive "p")
  (kill-line 0))
(global-set-key "\C-l" 'backward-kill-line)

; Insert the secondary X clipboard at point
(global-set-key "\M-`" '(lambda () (interactive) (shell-command "xclip -o" t)))

; Enable smart syntax based deletion commands.
;IMPORTANT! This overrides default bindings!
;<http://www.zafar.se/bkz/Articles/EmacsTips>
(global-set-key [(meta backspace)] 'kill-syntax-backward)
(global-set-key [(meta d)] 'kill-syntax-forward)
(defun kill-syntax-forward ()
  "Kill characters with syntax at point."
  (interactive)
  (kill-region (point)
               (progn (skip-syntax-forward (string (char-syntax (char-after))))
                      (point))))
(defun kill-syntax-backward ()
  "Kill characters with syntax at point."
  (interactive)
  (kill-region (point)
               (progn (skip-syntax-backward (string (char-syntax (char-before))))
                      (point))))

;;"Redefine the Home/End keys to (nearly) the same as visual studio
;;behavior... special home and end by Shan-leung Maverick WOO
;;<sw77@cornell.edu>"
;;This is complex. In short, the 1st invocation of Home/End moves
;;to the beginning of the *text* line (ignoring prefixed whitespace); 2nd invocation moves
;;cursor to the beginning of the *absolute* line. Most of the time
;;this won't matter or even be noticeable, but when it does (in
;;comments, for example) it will be quite convenient.
(global-set-key [home] 'my-smart-home)
(global-set-key [end] 'my-smart-end)
(defun my-smart-home ()
  "Odd home to beginning of line, even home to beginning of
text/code."
  (interactive)
  (if (and (eq last-command 'my-smart-home)
           (/= (line-beginning-position) (point)))
      (beginning-of-line)
    (beginning-of-line-text)))
(defun my-smart-end ()
  "Odd end to end of line, even end to begin of text/code."
  (interactive)
  (if (and (eq last-command 'my-smart-end)
           (= (line-end-position) (point)))
      (end-of-line-text)
    (end-of-line)))
(defun end-of-line-text ()
  "Move to end of current line and skip comments and trailing space.
Require `font-lock'."
  (interactive)
  (end-of-line)
  (let ((bol (line-beginning-position)))
    (unless (eq font-lock-comment-face (get-text-property bol 'face))
      (while (and (/= bol (point))
                  (eq font-lock-comment-face
                      (get-text-property (point) 'face)))
        (backward-char 1))
      (unless (= (point) bol)
        (forward-char 1) (skip-chars-backward " \t\n"))))) ;;Done with home and end keys.

;I like M-g for goto-line
(global-set-key "\M-g" 'goto-line)

;Change C-x C-b behavior so it uses bs; shows only interesting buffers.
(global-set-key "\C-x\C-b" 'bs-show)

;IMPORTANT! This overrides the default binding!
;The idea is to sort of imitate Stumpwm for buffer management, so to speak.
(global-set-key "\C-n" 'bury-buffer)
(global-set-key "\C-p" '(lambda () (interactive) (switch-to-buffer (other-buffer))))

; Need because of Urxvt
(global-set-key "\M-o\ c" 'forward-word)
(global-set-key "\M-o\ d" 'backward-word) ;this overrides some fontlock binding
(global-set-key [clearline] 'end-of-buffer) ;dunno, but C-Home appears as this to Urxvt

;I never use set-fill-column and I hate hitting it by accident.
(global-set-key "\C-x\ f" 'find-file)

; I also never use overwrite! What the heck. Plus, my cat keeps stepping on the 'Insert' button.
; change it to something more useful...
(define-key global-map [(insert)] 'yank)
(define-key global-map [(control insert)] 'yank)

;Need edmacro to work with iswitchb buffer switching
(require 'edmacro) ;Not via idle-require, because it's needed right away

;Enable iswitchb buffer mode. I find it easier to use than the
;regular buffer switching. While we are messing with buffer
;movement, the second sexp hides all the buffers beginning
;with "*". The third and fourth sexp does some remapping.
;My instinct is to go left-right in a completion buffer, not C-s/C-r
;; (eval-when-compile 'iswitchb)
;; (autoload 'iswitchb "iswitchb" "")
;; (eval-after-load 'iswitchb '(progn
;;                               (iswitchb-mode 1)
;;                               (defun iswitchb-local-keys ()
;;                                 (mapc (lambda (K)
;;                                         (let* ((key (car K)) (fun (cdr K)))
;;                                           (define-key iswitchb-mode-map (edmacro-parse-keys key)
;;                                             fun)))
;;                                       '(("<right>" . iswitchb-next-match)
;;                                         ("<left>"  . iswitchb-prev-match)
;;                                         ("<up>"    . ignore             )
;;                                         ("<down>"  . ignore             ))))
;;                               (add-hook 'iswitchb-define-mode-map-hook 'iswitchb-local-keys)))

;Rebinds <RET> key to do automatic indentation in certain modes; not haskell-mode though - unreliable.
;<http://www.metasyntax.net/unix/dot-emacs.html>
(mapc
 (lambda (mode)
   (let ((mode-hook (intern (concat (symbol-name mode) "-hook"))))
     (add-hook mode-hook (lambda nil (local-set-key (kbd "RET") 'newline-and-indent)))))
 '(ada-mode c-mode c++-mode cperl-mode emacs-lisp-mode java-mode html-mode lisp-mode perl-mode
            php-mode prolog-mode ruby-mode scheme-mode sgml-mode sh-mode sml-mode tuareg-mode))


; since I hardly ever write elisp, and often start writing things in the *scratch* buffer, save time by defaulting to Markdown.
(setq initial-major-mode 'markdown-mode)
(setq initial-scratch-message "")

;"These tell Emacs to associate certain filename extensions with
;certain modes.  I use cc-mode.el (c++-mode) for C as well as C++
;code.  It is fairly all-encompassing, also working with other
;C-like languages, such as Objective C and Java."
(push '("crontab$" . sh-mode) auto-mode-alist)
(push '("\\.cabal$" . haskell-cabal-mode) auto-mode-alist)
(push '("\\.doc$" . text-mode) auto-mode-alist)
(push '("\\.dpatch\\'" . diff-mode) auto-mode-alist)
(push '("\\.csv$" . csv-mode) auto-mode-alist)
(push '("\\.el$" . emacs-lisp-mode) auto-mode-alist)
(push '("\\.emacs" . emacs-lisp-mode) auto-mode-alist)
(push '("\\.fonts.conf$" . sgml-mode) auto-mode-alist)
(push '("\\.h$" . c++-mode) auto-mode-alist)
(push '("\\.hs$" . haskell-mode) auto-mode-alist)
(push '("\\.lhs$" . literate-haskell-mode) auto-mode-alist)
(push '("\\.lisp" . lisp-mode) auto-mode-alist)
(push '("\\.perl$" . perl-mode) auto-mode-alist)
(push '("\\.pl$" . perl-mode) auto-mode-alist)
(push '("\\.plan$" . text-mode) auto-mode-alist)
(push '("\\.screenrc$" . sh-mode) auto-mode-alist)
(push '("\\.sh$" . sh-mode) auto-mode-alist)
(push '("\\.ss$" . scheme-mode) auto-mode-alist)
(push '("\\.text$" . text-mode) auto-mode-alist)
(push '("\\.txt$" . text-mode) auto-mode-alist)
(push '("\\CHANGELOG" . c++-mode) auto-mode-alist)
(push '("\\INSTALL" . text-mode) auto-mode-alist)
(push '("\\README$" . text-mode) auto-mode-alist)
(push '("\\TODO$" . markdown-mode) auto-mode-alist)
(push '("\\.page$" . markdown-mode) auto-mode-alist)
(push '("\\.markdown$" . markdown-mode) auto-mode-alist)
(push '("\\.m$" . octave-mode) auto-mode-alist)
(push '("\\.journal$" . ledger-mode) auto-mode-alist)
(push '("\\.proselintrc$" . js-mode) auto-mode-alist) ; JSON mode

(setq completion-ignored-extensions (append completion-ignored-extensions
                                            '(".CKP" ".u" ".press" ".imp" ".BAK" ".bak")))
(put 'eval-expression 'disabled nil)

;"Set up highlighting of special words for selected modes."
; <http://www.metasyntax.net/unix/dot-emacs.html>
(make-face 'taylor-special-words)
(set-face-attribute 'taylor-special-words nil :foreground "White" :background "Firebrick")
(let ((pattern "\\<\\(FIXME\\|TODO\\|NOTE\\|WARNING\\|BUGS\\|TO DO\\|FIXME\\|FIX_ME\\|FIX ME\\|HACK\\|undefined\\)"))
  (mapc
   (lambda (mode)
     (font-lock-add-keywords mode `((,pattern 1 'taylor-special-words prepend))))
   '(ada-mode c-mode emacs-lisp-mode java-mode haskell-mode
              literate-haskell-mode html-mode lisp-mode php-mode python-mode ruby-mode
              scheme-mode sgml-mode sh-mode sml-mode markdown-mode ledger-mode)))

(defun byte-compile-visited-file ()
  (let ((byte-compile-verbose t))
    (byte-compile-file buffer-file-name)))
(add-hook 'emacs-lisp-mode-hook
          (lambda ()
            (when buffer-file-name
              (add-hook 'after-save-hook
                        'byte-compile-visited-file
                        nil t))))

;<http://www.cabochon.com/~stevey/blog-rants/my-dot-emacs-file.html>
(defun rename-file-and-buffer (new-name)
  "Renames both current buffer and file it is visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not filename)
        (message "Buffer '%s' is not visiting a file!" name)
      (if (get-buffer new-name)
          (message "A buffer named '%s' already exists!" new-name)
        (progn
          (rename-file name new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))
(global-set-key "\C-x\ W" 'rename-file-and-buffer)

;Make completion buffers in a shell disappear after 10 seconds.
;<http://snarfed.org/space/why+I+don't+run+shells+inside+Emacs>
(add-hook 'completion-setup-hook
          (lambda () (run-at-time 10 nil
                                  (lambda () (delete-windows-on "*Completions*")))))

;Add good shortcut for flyspell. The hook makes sure when flyspell-mode is on,
;the buffer gets scanned.
(defun flyspell nil "Do the expected default, which is run flyspell on the whole buffer."
  (interactive)
  (flyspell-buffer))
(add-hook 'flyspell-mode-hook 'flyspell-buffer)

; After we add a word to Ispell or correct something, flyspell's highlighting may become
; outdated. Let's re-run highlighting after a correction.
(defadvice ispell (after advice)
  (flyspell-buffer))
(ad-activate 'ispell t)
(defadvice ispell-word (after advice)
  (flyspell-buffer))
(ad-activate 'ispell-word t)

;Turns tabs into spaces
(defun ska-untabify ()
  "My untabify function as discussed and described at
 http://www.jwz.org/doc/tabs-vs-spaces.html
 and improved by Claus Brunzema:
 - return nil to get `write-contents-hooks' to work correctly
   (see documentation there)
 - `make-local-hook' instead of `make-local-variable'
 - when instead of if"
  (save-excursion
    (goto-char (point-min))
    (when (search-forward "\t" nil t)
      (untabify (1- (point)) (point-max)))
    nil))
(add-hook 'after-save-hook
          '(lambda ()
             (add-hook 'write-contents-functions 'ska-untabify nil t)))

;;;;;;;;;;;;;;;;;;;
;;;;;PACKAGES;;;;;;
;;;;;;;;;;;;;;;;;;;
;;I send all customizations dealing with Lisp files which set new modes
;;here. All the preceding dealt with usual Emacs options.

;; This was installed by package-install.el.
;; This provides support for the package system and
;; interfacing with ELPA, the package archive.
;; Move this code earlier if you want to reference
;; packages in your .emacs.
; <http://tromey.com/elpa/>
(setq load-path (push "~/.emacs.d/elpa" load-path))

(require 'package)
(when (require 'package)
  (if (fboundp 'package-initialize) (package-initialize)))
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("marmalade" . "https://marmalade-repo.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))

; Idle-require is provided through ELPA
; Load things in downtime.
(autoload 'idle-require "" "")
(eval-after-load "idle-require"
  (progn (if (fboundp 'idle-require-mode) (idle-require-mode 1))
         (setq idle-require-symbols nil) ; clear the massive default set of autoloads
         ))

;"Recentf is a minor mode that builds a list of recently opened
;files. This list is is automatically saved across Emacs sessions.
;You can then access this list through a menu."
;<http://www.emacswiki.org/cgi-bin/wiki/recentf-buffer.el>
(require 'recentf)
(eval-after-load "recentf" '(progn
                              (setq recentf-auto-cleanup 'never) ;To protect tramp
                              (recentf-mode 1)))

(require 'session)
(add-hook 'after-init-hook 'session-initialize)

;..."you can edit filenames from within the dired buffer using wdired-change-to-wdired-mode.
;I like to have this bound to e which previously would have done the same thing as RET."
;<http://www.shellarchive.co.uk/Emacs.html#sec5>
(add-hook 'dired-mode-hook
          '(lambda ()
             (define-key dired-mode-map "e" 'wdired-change-to-wdired-mode)))

;Incremental search of minibuffer history.
;<http://www.sodan.org/~knagano/emacs/minibuf-isearch/>
(idle-require "minibuf-isearch")

;Haskell-mode is provided through Ubuntu's haskell-mode package.
;This changes some of the modules loaded.
;; (idle-require "haskell-mode")
(idle-require 'haskell-mode)
;; (load "~/.emacs.d/haskell-mode/haskell-site-file.elc")
(eval-after-load "haskell-mode" '(progn
                                   (require 'inf-haskell)
                                   (require 'haskell-interactive-mode)
                                   (require 'haskell-process)
                                   (add-hook 'haskell-mode-hook 'interactive-haskell-mode)
                                   (setq auto-mode-alist
                                         (append auto-mode-alist
                                                 '(("\\.[hg]s$"  . haskell-mode)
                                                   ("\\.hi$"     . haskell-mode)
                                                   ("\\.l[hg]s$" . literate-haskell-mode))))

                                   (autoload 'haskell-mode "haskell-mode"
                                     "Haskell programing major mode." t)
                                   (autoload 'literate-haskell-mode "haskell-mode"
                                     "Literate Haskell script major mode." t)

                                   ;Spellcheck comments
                                   (add-hook 'haskell-mode-hook 'flyspell-prog-mode)

                                   ;<http://www.emacswiki.org/cgi-bin/wiki/HaskellMode>
                                   (add-hook 'haskell-mode-hook
                                             #'(lambda ()
                                                 (setq comment-padding " "
                                                       comment-start "--")))

                                   ;Use my neat Unicode stuff
                                   (setq haskell-font-lock-symbols 'unicode)

                                   ;Default behaviour is to always jump to the GHCi window.
                                   ;Jump back automatically unless errors.
                                   (defadvice haskell-ghci-load-file (after name)
                                     (other-window 1))
                                   (ad-activate 'haskell-ghci-load-file t)

                                   ; fix https://github.com/haskell/haskell-mode/issues/248
                                   (add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)

                                   ; Highlight trailing whitespace in haskell files
                                   (add-hook 'haskell-mode-hook
                                             '(lambda ()
                                                (setq show-trailing-whitespace t)))))

;Programming language modes use flyspell-prog-mode and not normal spell-check.
(add-hook 'sh-mode-hook (lambda () (flyspell-prog-mode)))

;"Why not use the cursor type and color to let you know what the current context is?
;A bar cursor (vertical bar between characters) is handy for editing, but it is not
;very noticeable in the middle of a sea of text. Why not change it to a box cursor
;(on top of a character) when Emacs is idle, so you can spot it easier?"
;<http://www.emacswiki.org/cgi-bin/wiki/ChangingCursorDynamically>
;<http://www.emacswiki.org/cgi-bin/emacs/cursor-chg.el>
(idle-require "cursor-chg")
(eval-after-load "cursor-chg"
  '(progn
     (toggle-cursor-type-when-idle 1) ; Turn on cursor when Emacs is idle
     (change-cursor-mode 1) ; Turn on change for overwrite, read-only, and input mode
     (setq curchg-input-method-cursor-color "palegreen1"
           curchg-input-method-cursor-color "palegreen1")))

;;Saveplace: Cursor moves to remembered place. Very useful for large files.
(require 'saveplace)
(setq-default save-place t)

;; http://www.emacswiki.org/emacs-en/download/highlight-tail.el
;; (require 'highlight-tail)
;; ; red rather than default yellow
;; (setq highlight-tail-colors '(("black" . 0)
;;                                ("red" . 30)
;;                                ("black" . 66)))
;; (add-hook 'markdown-mode-hook 'highlight-tail-mode)

(autoload 'ledger-mode "ledger-mode" "A major mode for Ledger" t)
; (add-to-list 'load-path
;              (expand-file-name "/home/gwern/src/ledger/lisp/"))

;;;;;;;;;;;;;;;;;;;
;;;; CUSTOM ;;;;;;;
;;;;;;;;;;;;;;;;;;;
(put 'scroll-left 'disabled t)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(add-log-current-defun-function nil)
 '(auto-compression-mode t)
 '(auto-save-interval 30)
 '(backup-by-copying t)
 '(backup-by-copying-when-linked t)
 '(backup-directory-alist (quote (("." . "~/.saves"))))
 '(before-save-hook (quote (time-stamp delete-trailing-whitespace)))
 '(blink-cursor-delay 2)
 '(blink-cursor-interval 0.7)
 '(browse-url-xterm-program "urxvt")
 '(byte-compile-generate-call-tree nil)
 '(change-log-default-name "CHANGELOG")
 '(color-theme-history-max-length 10)
 '(column-number-mode t)
 '(completion-ignored-extensions
   (quote
    (".o" ".hi" ".elc" ".class" "java~" ".ps" ".pdf" ".abs" ".mx" ".~jv" "#" ".gz" ".tgz" ".fasl" ".CKP" ".u" ".press" ".imp" ".BAK" ".bak")))
 '(completion-max-candidates 15)
 '(completion-min-chars 3)
 '(completion-resolve-old-method (quote reject))
 '(delete-old-versions t)
 '(dired-recursive-copies (quote always))
 '(display-buffer-reuse-frames t)
 '(display-hourglass t)
 '(display-time-mode t)
 '(file-cache-find-command-posix-flag t)
 '(file-cache-ignore-case t)
 '(file-precious-flag t)
 '(fill-column 80)
 '(font-lock-maximum-size (quote ((t))))
 '(font-lock-verbose 10000)
 '(frame-background-mode (quote dark))
 '(gc-cons-threshold 30000000)
 '(global-font-lock-mode t)
 '(haskell-doc-show-global-types t)
 '(haskell-hoogle-command "hoogle")
 '(haskell-program-name "ghci \"+.\"")
 '(hourglass-delay 2)
 '(icomplete-compute-delay 0.2)
 '(icomplete-mode t)
 '(indent-tabs-mode nil)
 '(inferior-haskell-wait-and-jump t)
 '(inhibit-startup-screen t)
 '(initial-scratch-message "")
 '(ispell-following-word t)
 '(ispell-highlight-p t)
 '(ispell-program-name "aspell")
 '(ispell-silently-savep t)
 '(jde-compile-option-command-line-args (quote ("")))
 '(jde-compile-option-verbose t)
 '(jde-compiler (quote ("javac" "/usr/bin/javac")))
 '(kept-new-versions 16)
 '(kept-old-versions 16)
 '(kill-ring-max 120)
 '(large-file-warning-threshold 30000000)
 '(ledger-highlight-xact-under-point nil)
 '(markdown-command
   "pandoc --mathml --to=html5 --standalone --smart --number-sections --toc --reference-links --css=https://www.gwern.net/static/css/default.css")
 '(markdown-enable-math t)
 '(markdown-italic-underscore t)
 '(message-log-max 1024)
 '(mouse-yank-at-point t)
 '(package-selected-packages
   (quote
    (## csv-mode session markdown-mode ledger minibuf-isearch idle-require)))
 '(read-file-name-completion-ignore-case t)
 '(save-place-file "~/.emacs.d/emacs-places")
 '(save-place-limit 1024)
 '(scroll-down-aggressively 0.4)
 '(scroll-up-aggressively 0.5)
 '(select-enable-clipboard t)
 '(sentence-end-double-space nil)
 '(server-temp-file-regexp "^/tmp/.*|/draft$")
 '(show-paren-delay 1)
 '(show-paren-mode t)
 '(show-paren-priority 500)
 '(show-paren-ring-bell-on-mismatch t)
 '(show-paren-style (quote mixed))
 '(tab-width 4)
 '(text-mode-hook
   (quote
    (lambda nil
      (when
          (not
           (and
            (stringp buffer-file-name)
            (string-match "\\.csv\\'" buffer-file-name)))
        (flyspell-mode
         (text-mode-hook-identify))))))
 '(tramp-default-method "ssh")
 '(vc-follow-symlinks t)
 '(vc-make-backup-files t)
 '(version-control t)
 '(visible-bell t)
 '(window-min-height 3)
 '(words-include-escapes t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(bold ((t (:weight bold))))
 '(bold-italic ((t (:slant italic :weight bold))))
 '(border ((t nil)))
 '(brace-face ((((class color)) (:foreground "white"))))
 '(bracket-face ((((class color)) (:foreground "DeepSkyBlue3"))))
 '(buffer-menu-buffer ((t (:inherit font-lock-function-name-face))))
 '(button ((t (:inherit bold))))
 '(comint-highlight-input ((t (:inherit bold))))
 '(compilation-info ((((class color) (min-colors 88) (background dark)) (:foreground "palegreen"))))
 '(compilation-warning ((((class color) (min-colors 16)) (:inherit bold :foreground "Orange"))))
 '(cursor ((t (:background "palegreen"))))
 '(custom-link ((((min-colors 88) (class color) (background dark)) (:underline t :weight bold))))
 '(ecb-default-highlight-face ((((class color) (background dark)) (:background "darkslateblue"))))
 '(escape-glyph ((((background dark)) (:foreground "lightsteelblue3"))))
 '(eshell-ls-archive ((((class color) (background dark)) (:foreground "salmon"))))
 '(eshell-ls-directory ((((class color) (background dark)) (:foreground "Skyblue"))))
 '(eshell-ls-executable ((((class color) (background dark)) (:foreground "palegreen"))))
 '(eshell-ls-missing ((((class color) (background dark)) (:foreground "tomato"))))
 '(eshell-ls-symlink ((((class color) (background dark)) (:foreground "Cyan"))))
 '(eshell-prompt ((t (:foreground "aquamarine2"))))
 '(fg:erc-color-face1 ((t (:foreground "grey30"))))
 '(font-lock-builtin-face ((((class grayscale) (background light)) (:foreground "LightGray" :weight bold)) (((class grayscale) (background dark)) (:foreground "DimGray" :weight bold)) (((class color) (min-colors 88) (background light)) (:foreground "Orchid")) (((class color) (min-colors 88) (background dark)) (:foreground "LightSteelBlue")) (((class color) (min-colors 16) (background light)) (:foreground "Orchid")) (((class color) (min-colors 16) (background dark)) (:foreground "LightSteelBlue")) (((class color) (min-colors 8)) (:foreground "cyan" :weight bold)) (t (:weight bold))))
 '(font-lock-comment-delimiter-face ((default (:foreground "tan2")) (((class color) (min-colors 16)) nil)))
 '(font-lock-constant-face ((((type x) (class color) (min-colors 88) (background dark)) (:foreground "Aquamarine3"))))
 '(font-lock-keyword-face ((((type x) (class color) (min-colors 88) (background dark)) (:foreground "turquoise3"))))
 '(font-lock-regexp-grouping-backslash ((t (:foreground "burlywood1"))))
 '(font-lock-string-face ((((type x) (class color) (min-colors 88) (background dark)) (:foreground "burlywood3")) (((type tty)) (:foreground "palegreen"))))
 '(font-lock-type-face ((((class color) (min-colors 88) (background dark)) (:foreground "PaleGreen3"))))
 '(font-lock-variable-name-face ((((type x) (min-colors 88) (background dark)) (:foreground "LightGoldenrod3"))))
 '(font-lock-warning-face ((((type x) (class color) (min-colors 88) (background dark)) (:background "firebrick4" :foreground "white")) (((type tty)) (:background "red" :foreground "white" :weight bold))))
 '(fringe ((((class color) (background dark)) (:background "grey20"))))
 '(header-line ((t (:inherit variable-pitch :background "grey10" :foreground "aquamarine3" :box (:line-width 2 :color "aquamarine4")))))
 '(help-argument-name ((((supports :slant italic)) (:inherit font-lock-variable-name-face))))
 '(highlight ((((type x) (class color) (min-colors 88) (background dark)) (:background "grey20"))))
 '(highlight-changes ((((min-colors 88) (class color)) (:background "grey20"))))
 '(highline-face ((t (:background "grey20"))))
 '(hl-line ((t (:background "#101040"))))
 '(info-menu-star ((((class color)) (:foreground "lightgoldenrod"))))
 '(info-node ((((class color) (background dark)) (:inherit bold :foreground "white" :slant italic))))
 '(info-xref ((((min-colors 88) (class color) (background dark)) (:foreground "lightgoldenrod2"))))
 '(info-xref-visited ((default (:foreground "lightgoldenrod3")) (((class color) (background dark)) nil)))
 '(italic ((((supports :underline t)) (:slant italic))))
 '(match ((((class color) (min-colors 88) (background dark)) (:background "royalblue"))))
 '(menu ((t (:background "grey30" :foreground "gold"))))
 '(minibuffer-prompt ((((background dark)) (:foreground "aquamarine2"))))
 '(mode-line ((((class color) (min-colors 88)) (:inherit variable-pitch :background "black" :foreground "palegreen3" :box (:line-width 2 :color "palegreen4")))))
 '(mode-line-buffer-id ((t (:inherit bold))))
 '(mode-line-inactive ((((type x)) (:inherit variable-pitch :background "grey20" :foreground "palegreen4" :box (:line-width 2 :color "grey40")))))
 '(paren-face ((((class color)) (:foreground "darkseagreen"))))
 '(paren-face-match ((((class color)) (:background "green"))))
 '(paren-face-mismatch ((((class color)) (:foreground "white" :background "red"))))
 '(paren-match ((t (:background "green"))))
 '(paren-mismatch ((t (:background "red"))))
 '(progmode-special-chars-face ((((class color)) (:foreground "grey90"))))
 '(region ((((class color) (min-colors 88) (background dark)) (:background "darkslateblue"))))
 '(scroll-bar ((t (:inherit Header\ Line :stipple nil :background "black" :foreground "lightgreen" :inverse-video nil :slant italic :weight ultra-bold :height 1 :width condensed))))
 '(semicolon-face ((((class color)) (:foreground "white"))))
 '(sh-escaped-newline ((t (:foreground "tomato"))))
 '(sh-heredoc ((((min-colors 88) (class color) (background dark)) (:inherit font-lock-string-face :background "grey20"))))
 '(sh-quoted-exec ((((class color) (background dark)) (:foreground "salmon1"))))
 '(shadow ((((class color grayscale) (min-colors 88) (background dark)) (:foreground "grey50"))))
 '(show-paren-match ((((class color) (background dark)) (:background "deepskyblue1"))))
 '(show-paren-mismatch ((((class color)) (:background "firebrick3"))))
 '(tooltip ((((class color)) (:inherit variable-pitch :background "gray30" :foreground "white"))))
 '(trailing-whitespace ((((class color) (background dark)) (:background "grey30"))))
 '(tuareg-font-lock-governing-face ((t (:foreground "orange"))))
 '(ude-error-face ((t (:background "firebrick4" :foreground "white" :weight normal))))
 '(ude-font-lock-face-1 ((t (:foreground "Plum2"))))
 '(variable-pitch ((t (:height 0.8 :family "arial"))))
 '(vertical-border ((nil (:foreground "grey20"))))
 '(which-func ((((class color) (min-colors 88) (background dark)) (:foreground "aquamarine"))))
 '(woman-bold ((((background dark)) (:foreground "palegreen"))))
 '(woman-italic ((((background dark)) (:foreground "lightgoldenrod"))))
 '(woman-italic-no-ul ((t (:foreground "lightgoldenrod"))) t))
(put 'downcase-region 'disabled nil)
;end .emacs
