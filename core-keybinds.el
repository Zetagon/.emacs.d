;;; core-keybinds.el -*- lexical-binding: t; -*-

;; A centralized keybinds system, integrated with `which-key' to preview
;; available keybindings. All built into one powerful macro: `map!'. If evil is
;; never loaded, then evil bindings set with `map!' are ignored (i.e. omitted
;; entirely for performance reasons).

(defvar doom-leader-key "SPC"
  "The leader prefix key for Evil users.

This needs to be changed from $DOOMDIR/init.el.")

(defvar doom-leader-alt-key "M-SPC"
  "An alternative leader prefix key, used for Insert and Emacs states, and for
non-evil users.

This needs to be changed from $DOOMDIR/init.el.")

(defvar doom-localleader-key "SPC m"
  "The localleader prefix key, for major-mode specific commands.

This needs to be changed from $DOOMDIR/init.el.")

(defvar doom-localleader-alt-key "M-SPC m"
  "The localleader prefix key, for major-mode specific commands. Used for Insert
and Emacs states, and for non-evil users.

This needs to be changed from $DOOMDIR/init.el.")

(defvar doom-leader-map (make-sparse-keymap)
  "An overriding keymap for <leader> keys.")

(defvar doom-which-key-leader-prefix-regexp nil)


;;
;;; Universal, non-nuclear escape

;; `keyboard-quit' is too much of a nuclear option. I wanted an ESC/C-g to
;; do-what-I-mean. It serves four purposes (in order):
;;
;; 1. Quit active states; e.g. highlights, searches, snippets, iedit,
;;    multiple-cursors, recording macros, etc.
;; 2. Close popup windows remotely (if it is allowed to)
;; 3. Refresh buffer indicators, like git-gutter and flycheck
;; 4. Or fall back to `keyboard-quit'
;;
;; And it should do these things incrementally, rather than all at once. And it
;; shouldn't interfere with recording macros or the minibuffer. This may require
;; you press ESC/C-g two or three times on some occasions to reach
;; `keyboard-quit', but this is much more intuitive.

(defvar doom-escape-hook nil
  "A hook run after C-g is pressed (or ESC in normal mode, for evil users). Both
trigger `doom/escape'.

If any hook returns non-nil, all hooks after it are ignored.")

(defun doom/escape ()
  "Run `doom-escape-hook'."
  (interactive)
  (cond ((minibuffer-window-active-p (minibuffer-window))
         ;; quit the minibuffer if open.
         (abort-recursive-edit))
        ;; Run all escape hooks. If any returns non-nil, then stop there.
        ((run-hook-with-args-until-success 'doom-escape-hook))
        ;; don't abort macros
        ((or defining-kbd-macro executing-kbd-macro) nil)
        ;; Back to the default
        ((keyboard-quit))))

(global-set-key [remap keyboard-quit] #'doom/escape)


;;
;;; General + leader/localleader keys

(require 'general)
;; Convenience aliases
(defalias 'define-key! #'general-def)
(defalias 'unmap! #'general-unbind)

;; We avoid `general-create-definer' to ensure that :states, :wk-full-keys and
;; :keymaps cannot be overwritten.
(defmacro define-leader-key! (&rest args)
  `(general-define-key
    :states nil
    :wk-full-keys nil
    :keymaps 'doom-leader-map
    ,@args))

(general-create-definer define-localleader-key!
  :major-modes t
  :prefix doom-localleader-alt-key)

;; :non-normal-prefix doesn't apply to non-evil sessions (only evil's emacs
;; state), so we must redefine `define-localleader-key!' to behave differently
;; where evil is present.
(with-eval-after-load "evil"
  (general-create-definer define-localleader-key!
    :states '(normal visual motion emacs)
    :major-modes t
    :prefix doom-localleader-key
    :non-normal-prefix doom-localleader-alt-key))

;; We use a prefix commands instead of general's :prefix/:non-normal-prefix
;; properties because general is incredibly slow binding keys en mass with them
;; in conjunction with :states -- an effective doubling of Doom's startup time!
(define-prefix-command 'doom/leader 'doom-leader-map)
(define-key doom-leader-map [override-state] 'all)

;; Bind `doom-leader-key' and `doom-leader-alt-key' as late as possible to give
;; the user a chance to modify them.
(defun doom|init-leader-keys ()
  "Bind `doom-leader-key' and `doom-leader-alt-key'."
  (let ((map general-override-mode-map))
    (if (not (featurep 'evil))
        (define-key map (kbd doom-leader-alt-key) 'doom/leader)
      (evil-define-key* '(normal visual motion) map (kbd doom-leader-key) 'doom/leader)
      (evil-define-key* '(emacs insert) map (kbd doom-leader-alt-key) 'doom/leader))
    (general-override-mode +1))
  (unless (stringp doom-which-key-leader-prefix-regexp)
    (setq doom-which-key-leader-prefix-regexp
          (concat "\\(?:"
                  (cl-loop for key in (append (list doom-leader-key doom-leader-alt-key)
                                              (where-is-internal 'doom/leader))
                           if (stringp key) collect key into keys
                           else collect (key-description key) into keys
                           finally return (string-join keys "\\|"))
                  "\\)"))))
(add-hook 'doom-after-init-modules-hook #'doom|init-leader-keys)

;; However, the prefix command approach (along with :wk-full-keys in
;; `define-leader-key!') means that which-key is only informed of the key
;; sequence minus `doom-leader-key'/`doom-leader-alt-key'. e.g. binding to `SPC
;; f s' creates a wildcard label for any key that ends in 'f s'.
;;
;; So we forcibly inject `doom-leader-key' and `doom-leader-alt-key' into the
;; which-key key replacement regexp for keybinds created on `doom-leader-map'.
;; This is a dirty hack, but I'd rather this than general being responsible for
;; 50% of Doom's startup time.
(defun doom*general-extended-def-:which-key (_state keymap key edef kargs)
  (with-eval-after-load "which-key"
    (let* ((wk (general--getf2 edef :which-key :wk))
           (major-modes (general--getf edef kargs :major-modes))
           (keymaps (plist-get kargs :keymaps))
           ;; index of keymap in :keymaps
           (keymap-index (cl-dotimes (ind (length keymaps))
                           (when (eq (nth ind keymaps) keymap)
                             (cl-return ind))))
           (mode (let ((mode (if (and major-modes (listp major-modes))
                                 (nth keymap-index major-modes)
                               major-modes)))
                   (if (eq mode t)
                       (general--remove-map keymap)
                     mode)))
           (key (key-description key))
           (key-regexp (concat (if (general--getf edef kargs :wk-full-keys)
                                   "\\`"
                                 ;; Modification begin
                                 (if (memq 'doom-leader-map keymaps)
                                     (concat "\\`" doom-which-key-leader-prefix-regexp " ")))
                                 ;; Modification end
                               (regexp-quote key)
                               "\\'"))
           (prefix (plist-get kargs :prefix))
           (binding (or (when (and (plist-get edef :def)
                                   (not (plist-get edef :keymp)))
                          (plist-get edef :def))
                        (when (and prefix (string= key prefix))
                          (plist-get kargs :prefix-command))))
           (replacement (cond ((stringp wk)
                               (cons nil wk))
                              (wk)))
           (match/replacement
            (cons
             (cons (when (general--getf edef kargs :wk-match-keys)
                     key-regexp)
                   (when (and (general--getf edef kargs :wk-match-binding)
                              binding
                              (symbolp binding))
                     (symbol-name binding)))
             replacement)))
      (general--add-which-key-replacement mode match/replacement)
      (when (and (consp replacement) (not (functionp replacement)))
        (general--add-which-key-title-prefix mode key (cdr replacement))))))
(advice-add #'general-extended-def-:which-key :override #'doom*general-extended-def-:which-key)


;;
;;; Packages

;; (use-package which-key
  ;; :defer 1
  ;; :after-call pre-command-hook
  ;; :init
  ;; (setq which-key-sort-order #'which-key-prefix-then-key-order
        ;; which-key-sort-uppercase-first nil
        ;; which-key-add-column-padding 1
        ;; which-key-max-display-columns nil
        ;; which-key-min-display-lines 6
        ;; which-key-side-window-slot -10)
  ;; :config
  ;; ;; general improvements to which-key readability
  ;; (set-face-attribute 'which-key-local-map-description-face nil :weight 'bold)
  ;; (which-key-setup-side-window-bottom)
  ;; (setq-hook! 'which-key-init-buffer-hook line-spacing 3)
  ;; (which-key-mode +1))


;; `hydra'
(setq lv-use-seperator t)


;;
;;; `map!' macro

(defvar doom-evil-state-alist
  '((?n . normal)
    (?v . visual)
    (?i . insert)
    (?e . emacs)
    (?o . operator)
    (?m . motion)
    (?r . replace)
    (?g . global))
  "A list of cons cells that map a letter to a evil state symbol.")

(defun doom--keyword-to-states (keyword)
  "Convert a KEYWORD into a list of evil state symbols.

For example, :nvi will map to (list 'normal 'visual 'insert). See
`doom-evil-state-alist' to customize this."
  (cl-loop for l across (substring (symbol-name keyword) 1)
           if (cdr (assq l doom-evil-state-alist)) collect it
           else do (error "not a valid state: %s" l)))


;; Register keywords for proper indentation (see `map!')
(put :after        'lisp-indent-function 'defun)
(put :desc         'lisp-indent-function 'defun)
(put :leader       'lisp-indent-function 'defun)
(put :localleader  'lisp-indent-function 'defun)
(put :map          'lisp-indent-function 'defun)
(put :keymap       'lisp-indent-function 'defun)
(put :mode         'lisp-indent-function 'defun)
(put :prefix       'lisp-indent-function 'defun)
(put :unless       'lisp-indent-function 'defun)
(put :when         'lisp-indent-function 'defun)

;; specials
(defvar doom--map-forms nil)
(defvar doom--map-fn nil)
(defvar doom--map-batch-forms nil)
(defvar doom--map-state '(:dummy t))
(defvar doom--map-parent-state nil)
(defvar doom--map-evil-p nil)
(with-eval-after-load "evil" (setq doom--map-evil-p t))

(defun doom--map-process (rest)
  (let ((doom--map-fn doom--map-fn)
        doom--map-state
        doom--map-forms
        desc)
    (while rest
      (let ((key (pop rest)))
        (cond ((listp key)
               (doom--map-nested nil key))

              ((keywordp key)
               (pcase key
                 (:leader
                  (doom--map-commit)
                  (setq doom--map-fn 'define-leader-key!))
                 (:localleader
                  (doom--map-commit)
                  (setq doom--map-fn 'define-localleader-key!))
                 (:after
                  (doom--map-nested (list 'with-eval-after-load (pop rest)) rest)
                  (setq rest nil))
                 (:desc
                  (setq desc (pop rest)))
                 ((or :map :map* :keymap)
                  (doom--map-set :keymaps `(quote ,(doom-enlist (pop rest)))))
                 (:mode
                  (push (cl-loop for m in (doom-enlist (pop rest))
                                 collect (intern (concat (symbol-name m) "-map")))
                        rest)
                  (push :map rest))
                 ((or :when :unless)
                  (doom--map-nested (list (intern (doom-keyword-name key)) (pop rest)) rest)
                  (setq rest nil))
                 (:prefix
                  (cl-destructuring-bind (prefix . desc) (doom-enlist (pop rest))
                    (doom--map-set (if doom--map-fn :infix :prefix)
                                   prefix)
                    (when (stringp desc)
                      (setq rest (append (list :desc desc "" nil) rest)))))
                 (:textobj
                  (let* ((key (pop rest))
                         (inner (pop rest))
                         (outer (pop rest)))
                    (push `(map! (:map evil-inner-text-objects-map ,key ,inner)
                                 (:map evil-outer-text-objects-map ,key ,outer))
                          doom--map-forms)))
                 (_
                  (condition-case _
                      (doom--map-def (pop rest) (pop rest) (doom--keyword-to-states key) desc)
                    (error
                     (error "Not a valid `map!' property: %s" key)))
                  (setq desc nil))))

              ((doom--map-def key (pop rest) nil desc)
               (setq desc nil)))))

    (doom--map-commit)
    (macroexp-progn (nreverse (delq nil doom--map-forms)))))

(defun doom--map-append-keys (prop)
  (let ((a (plist-get doom--map-parent-state prop))
        (b (plist-get doom--map-state prop)))
    (if (and a b)
        `(general--concat nil ,a ,b)
      (or a b))))

(defun doom--map-nested (wrapper rest)
  (doom--map-commit)
  (let ((doom--map-parent-state (doom--map-state)))
    (push (if wrapper
              (append wrapper (list (doom--map-process rest)))
            (doom--map-process rest))
          doom--map-forms)))

(defun doom--map-set (prop &optional value)
  (unless (equal (plist-get doom--map-state prop) value)
    (doom--map-commit))
  (setq doom--map-state (plist-put doom--map-state prop value)))

(defun doom--map-def (key def &optional states desc)
  (when (or (memq 'global states)
            (null states))
    (setq states (cons 'nil (delq 'global states))))
  (when desc
    (let (unquoted)
      (cond ((and (listp def)
                  (keywordp (car-safe (setq unquoted (doom-unquote def)))))
             (setq def (list 'quote (plist-put unquoted :which-key desc))))
            ((setq def (cons 'list
                             (if (and (equal key "")
                                      (null def))
                                 `(:ignore t :which-key ,desc)
                               (plist-put (general--normalize-extended-def def)
                                          :which-key desc))))))))
  (dolist (state states)
    (push (list key def)
          (alist-get state doom--map-batch-forms)))
  t)

(defun doom--map-commit ()
  (when doom--map-batch-forms
    (cl-loop with attrs = (doom--map-state)
             for (state . defs) in doom--map-batch-forms
             if (or doom--map-evil-p (not state))
             collect `(,(or doom--map-fn 'general-define-key)
                       ,@(if state `(:states ',state)) ,@attrs
                       ,@(mapcan #'identity (nreverse defs)))
             into forms
             finally do (push (macroexp-progn forms) doom--map-forms))
    (setq doom--map-batch-forms nil)))

(defun doom--map-state ()
  (let ((plist
         (append (list :prefix (doom--map-append-keys :prefix)
                       :infix  (doom--map-append-keys :infix)
                       :keymaps
                       (append (plist-get doom--map-parent-state :keymaps)
                               (plist-get doom--map-state :keymaps)))
                 doom--map-state
                 nil))
        newplist)
    (while plist
      (let ((key (pop plist))
            (val (pop plist)))
        (when (and val (not (plist-member newplist key)))
          (push val newplist)
          (push key newplist))))
    newplist))

;;
(defmacro map! (&rest rest)
  "A convenience macro for defining keybinds, powered by `general'.

If evil isn't loaded, evil-specific bindings are ignored.

States
  :n  normal
  :v  visual
  :i  insert
  :e  emacs
  :o  operator
  :m  motion
  :r  replace
  :g  global  (binds the key without evil `current-global-map')

  These can be combined in any order, e.g. :nvi will apply to normal, visual and
  insert mode. The state resets after the following key=>def pair. If states are
  omitted the keybind will be global (no emacs state; this is different from
  evil's Emacs state and will work in the absence of `evil-mode').

Properties
  :leader [...]                   an alias for (:prefix doom-leader-key ...)
  :localleader [...]              bind to localleader; requires a keymap
  :mode [MODE(s)] [...]           inner keybinds are applied to major MODE(s)
  :map [KEYMAP(s)] [...]          inner keybinds are applied to KEYMAP(S)
  :keymap [KEYMAP(s)] [...]       same as :map
  :prefix [PREFIX] [...]          set keybind prefix for following keys
  :after [FEATURE] [...]          apply keybinds when [FEATURE] loads
  :textobj KEY INNER-FN OUTER-FN  define a text object keybind pair
  :if [CONDITION] [...]
  :when [CONDITION] [...]
  :unless [CONDITION] [...]

  Any of the above properties may be nested, so that they only apply to a
  certain group of keybinds.

Example
  (map! :map magit-mode-map
        :m  \"C-r\" 'do-something           ; C-r in motion state
        :nv \"q\" 'magit-mode-quit-window   ; q in normal+visual states
        \"C-x C-r\" 'a-global-keybind
        :g \"C-x C-r\" 'another-global-keybind  ; same as above

        (:when IS-MAC
         :n \"M-s\" 'some-fn
         :i \"M-o\" (lambda (interactive) (message \"Hi\"))))"
  (doom--map-process rest))
(defun doom-enlist (exp)
  "Return EXP wrapped in a list, or as-is if already a list."
  (declare (pure t) (side-effect-free t))
  (if (listp exp) exp (list exp)))

(provide 'core-keybinds)
;;; core-keybinds.el ends here
