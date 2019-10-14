;;; init.el --- description -*- lexical-binding: t; -*-



;; * Straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))
(straight-use-package 'use-package)

;; Always use straight.el with use-package
(setq straight-use-package-by-default t)

;; * Evil-mode

(use-package evil
  :straight t
  :init
  (setq evil-want-keybinding nil)
  :config
  (evil-mode))
(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))
;; * General.el
(use-package general)
(require 'core-keybinds "~/.emacs.d/core-keybinds")
;; ** Keybindings
(general-evil-setup)

(map!
 :m "SPC" nil
 (:prefix "SPC"
   :m "." #'helm-find-files)
 "[" nil
 "]" nil
 "[e" #'previous-error
 "]e" #'next-error
 (:prefix "SPC c"
   :m "c" #'recompile
   :m "C" #'compile) 
 (:prefix "SPC w"
   :m "l" #'evil-window-right
   :m "k" #'evil-window-up
   :m "j" #'evil-window-down
   :m "h" #'evil-window-left)
 (:prefix "SPC b"
   :m "s" #'save-buffer
   :mn "b" #'switch-to-buffer)
   :i "M-/" #'company-complete
 )
(map!

 (:map outline-mode-map
   :n "[[" #'outline-up-heading))
;; * Helm

(use-package helm
  :config
  (helm-mode)
  (map!
   :n "SPC :" #'helm-M-x
   :n "SPC fr" #'helm-recentf))
;; * Company
(use-package company
  :config
  (global-company-mode))
;; * Misc. Configs
(menu-bar-mode -1)
(tool-bar-mode -1)
(setq-default display-line-numbers 'relative)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
;; * Magit
(use-package magit)
;; * Languages
;; ** Outline-mode for elisp
(add-hook 'emacs-lisp-mode-hook
	  (lambda ()
	    (outline-minor-mode)
	    (setq outline-regexp ";; \\*+")))
	  
(general-define-key
 :states 'normal
 :keymaps 'outline-minor-mode-map
 "zc" #'outline-hide-subtree
 "zo" #'outline-show-subtree
 "zM" #'my-outline-hide-body
 "zR" #'outline-show-all)

(defun my-outline-hide-body ()
  (interactive)
  (outline-hide-body)
  (evil-scroll-line-to-center nil))
;; ** C
(use-package ggtags
  :config
  (setq-local imenu-create-index-function #'ggtags-build-imenu-index)
  (add-hook 'c-mode-hook
	    #'ggtags-mode)
  (map!
   (:map ggtags-mode-map
     "M-." nil
     "M-." #'ggtags-find-tag-dwim
     :m "SPC /r" #'ggtags-find-reference
     :m "SPC /i" #'ggtags-find-definition
     :m "SPC /o" #'ggtags-find-other-symbol
     :m "SPC /d" #'ggtags-find-tag-dwim)
   (:map ggtags-navigation-map
     "M-n" nil
     "M-p" nil
     :mi "M-n" #'next-error
     :mi "M-p" #'previous-error)))

;; ** Lisp
(use-package lispy
  :config
  (add-hook 'emacs-lisp-mode-hook #'lispy-mode))
;; * End of config
(provide 'init)
;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-agenda-files (quote ("/home/leo/org/orgzly/Projects.org"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
