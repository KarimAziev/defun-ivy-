;;; defun-ivy+.el --- A macro to quickly create completions command with ivy-read.  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Karim Aziiev

;; Author: Karim Aziiev <karim.aziiev@gmail.com>
;; Keywords: abbrev

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(defun defun-ivy-format-actions (mapped-actions)
  (mapconcat (lambda (it)
               (let ((parts
                      (string-join
                       (seq-filter (lambda (str)
                                     (and (stringp str)
                                          (> (length str) 1)))
                                   it)
                       "\s")))
                 (concat "[" (string-join
                              (reverse
                               (split-string
                                parts
                                "[\\[]")) "\s"))))
             mapped-actions "\n"))

(defun defun-ivy-bind-actions (actions-list)
  (let* ((map (make-sparse-keymap))
         (actions
          (delq nil
                (mapcar
                 (lambda (a) (let*
                            ((key-str (pop a))
                             (func (seq-find 'functionp a))
                             (arity (help-function-arglist func))
                             (keybind (kbd key-str))
                             (action-key
                              (car (last (split-string
                                          key-str "" t))))
                             (descr
                              (format "%s [%s]"
                                      (or (seq-find
                                           'stringp a)
                                          (seq-find
                                           (lambda (it)
                                             (and
                                              (not (string-prefix-p "ivy-" it))
                                              (functionp (intern it))))
                                           (split-string
                                            (format "%s" func)
                                            "[\s\f\t\n\r\v)(']+" t))
                                          "")
                                      key-str))
                             (props (seq-filter 'keywordp a))
                             (no-exit (memq :no-exit props)))
                          (define-key map keybind
                            (cond
                             ((null arity)
                              (lambda ()
                                "Switch command."
                                (interactive)
                                (if no-exit
                                    (funcall func)
                                  (ivy-quit-and-run
                                    (funcall func)))))
                             ((and no-exit arity)
                              (lambda ()
                                "Persistent command."
                                (interactive)
                                (let ((current
                                       (or
                                        (ivy-state-current
                                         ivy-last)
                                        ivy-text))
                                      (window (ivy--get-window ivy-last)))
                                  (with-selected-window
                                      (ivy--get-window window)
                                    (funcall func current)))))
                             (t (lambda ()
                                  "Exit with action."
                                  (interactive)
                                  (ivy-exit-with-action func)))))
                          (list action-key func descr)))
                 actions-list))))
    (cons map actions)))

(defun defun-ivy-super-get-props (keywords pl)
  (let ((result)
        (keyword))
    (while (setq keyword (pop keywords))
      (when-let ((value (plist-get pl keyword)))
        (unless (null value)
          (setq result (append result (list keyword value))))))
    result))

(defmacro defun-ivy-read (name args &rest arg-list)
  "Defines and configure interactive command NAME,
which perfoms `ivy-read' with ARG-LIST. Usage:

  (defun-ivy+ command-name
     [:keyword [option]]...)

:collection         Either a list of strings, a function, an alist,
                    or a hash table, supplied for `minibuffer-completion-table'.
:actions            A list of actions `(KEYBINDING ACTION DESCRIPTION)'.
                    Can also contain keyword `:no-exit' to call action without
                    exiting minibuffer.
                    For example:
                    `((\"C-c s\" my-action-1 \"description 1\")
                      (\"C-c i\" my-action-2 \"description 2\" :no-exit))'.
:bind               A global keybinding for invoking you command.
:init               A function to call before invoking `ivy-read'.
:prompt             A string, normally ending in a colon and a space.
                    Default value for prompt is empty string.
:predicate          An argument for `ivy-read'.
:require-match      An argument for `ivy-read'.
:initial-input      An argument for `ivy-read'.
:history            An argument for `ivy-read'.
:preselect          An argument for `ivy-read'.
:def                An argument for `ivy-read'.
:keymap             An argument for `ivy-read'.
:update-fn          An argument for `ivy-read'.
:action             An argument for `ivy-read'.
:multi-action       An argument for `ivy-read'.
:unwind             An argument for `ivy-read'.
:re-builder         An argument for `ivy-read'.
:matcher            An argument for `ivy-read'.
:dynamic-collection An argument for `ivy-read'.
:extra-props        An argument for `ivy-read'.
:sort               An argument for `ivy-read'.
:sort-fn            An argument for `ivy-configure'.
:display-fn         An argument for `ivy-configure' (`display-transformer-fn').
:height             An argument for `ivy-configure'.
:exit-codes         An argument for `ivy-configure'.
:occur              An argument for `ivy-configure'.
:update-fn          An argument for `ivy-configure'.
:unwind-fn          An argument for `ivy-configure'.
:index-fn           An argument for `ivy-configure'.
:format-fn          An argument for `ivy-configure'.
:more-chars         An argument for `ivy-configure'.
:grep-p             An argument for `ivy-configure'.
:exit-codes         An argument for `ivy-configure'."
  (declare (indent 1))
  `(let* ((arg-list ',arg-list)
          (actions (defun-ivy-bind-actions
                     ,(plist-get arg-list :actions)))
          (global-key ,(plist-get arg-list :bind))
          (map))
     (setq map (car actions))
     (setq actions (cdr actions))
     (require 'ivy)
     (defalias ',name
       #'(lambda
           ,args
           (interactive)
           ,(plist-get arg-list :init)
           (ivy-read ,(or (plist-get arg-list :prompt) "\s")
                     ,(plist-get arg-list :collection)
                     ,@(defun-ivy-super-get-props
                         '(:predicate
                           :require-match
                           :initial-input
                           :history
                           :preselect
                           :def
                           :update-fn
                           :sort
                           :multi-action
                           :unwind
                           :re-builder
                           :matcher
                           :dynamic-collection
                           :extra-props)
                         arg-list)
                     :keymap map
                     :action (nth 1 (car actions))
                     :caller ',name)))
     (put ',name 'function-documentation
          (format "Performs completions with `ivy-read' and actions:\s\n%s"
                  (defun-ivy-format-actions actions)))
     (ivy-set-actions ',name actions)
     (ivy-configure ',name
       :display-transformer-fn ,(plist-get arg-list :display-fn)
       ,@(defun-ivy-super-get-props
           '(:exit-codes
             :grep-p
             :more-chars
             :format-fn
             :sort-fn
             :index-fn
             :unwind-fn
             :update-fn
             :occur
             :height)
           arg-list))
     (when global-key
       (global-set-key (kbd global-key) ',name))))

(defmacro defun-ivy+ (name &rest arg-list)
  "Defines and configure interactive command NAME,
which perfoms `ivy-read' with ARG-LIST. Usage:

  (defun-ivy+ command-name
     [:keyword [option]]...)

:collection         Either a list of strings, a function, an alist,
                    or a hash table, supplied for `minibuffer-completion-table'.
:actions            A list of actions `(KEYBINDING ACTION DESCRIPTION)'.
                    Can also contain keyword `:no-exit' to call action without
                    exiting minibuffer.
                    For example:
                    `((\"C-c s\" my-action-1 \"description 1\")
                      (\"C-c i\" my-action-2 \"description 2\" :no-exit))'.
:bind               A global keybinding for invoking you command.
:init               A function to call before invoking `ivy-read'.
:prompt             A string, normally ending in a colon and a space.
                    Default value for prompt is empty string.
:predicate          An argument for `ivy-read'.
:require-match      An argument for `ivy-read'.
:initial-input      An argument for `ivy-read'.
:history            An argument for `ivy-read'.
:preselect          An argument for `ivy-read'.
:def                An argument for `ivy-read'.
:keymap             An argument for `ivy-read'.
:update-fn          An argument for `ivy-read'.
:action             An argument for `ivy-read'.
:multi-action       An argument for `ivy-read'.
:unwind             An argument for `ivy-read'.
:re-builder         An argument for `ivy-read'.
:matcher            An argument for `ivy-read'.
:dynamic-collection An argument for `ivy-read'.
:extra-props        An argument for `ivy-read'.
:sort               An argument for `ivy-read'.
:sort-fn            An argument for `ivy-configure'.
:display-fn         An argument for `ivy-configure' (`display-transformer-fn').
:height             An argument for `ivy-configure'.
:exit-codes         An argument for `ivy-configure'.
:occur              An argument for `ivy-configure'.
:update-fn          An argument for `ivy-configure'.
:unwind-fn          An argument for `ivy-configure'.
:index-fn           An argument for `ivy-configure'.
:format-fn          An argument for `ivy-configure'.
:more-chars         An argument for `ivy-configure'.
:grep-p             An argument for `ivy-configure'.
:exit-codes         An argument for `ivy-configure'."
  (declare (indent 1))
  `(progn (require 'ivy)
          (defvar ,(intern (format "%s-actions" name)) nil)
          (setq ,(intern (format "%s-actions" name))
                (defun-ivy-bind-actions
                  ,(plist-get arg-list :actions)))
          (ivy-set-actions ',name
                           (cdr ,(intern (format "%s-actions" name))))
          (defun ,name ()
            "Performs completions with `ivy-read'."
            (interactive)
            ,(plist-get arg-list :init)
            (ivy-read ,(or (plist-get arg-list :prompt) "\s")
                      ,(plist-get arg-list :collection)
                      ,@(defun-ivy-super-get-props
                          '(:predicate
                            :require-match
                            :initial-input
                            :history
                            :preselect
                            :def
                            :update-fn
                            :sort
                            :multi-action
                            :unwind
                            :re-builder
                            :matcher
                            :dynamic-collection
                            :extra-props)
                          arg-list)
                      :keymap (car ,(intern (format "%s-actions" name)))
                      :action (nth 1 (cadr ,(intern (format "%s-actions" name))))
                      :caller ',name))
          ;; (put ',name 'function-documentation
          ;;      (format "Performs completions with `ivy-read' and actions:\s\n%s"
          ;;              (defun-ivy-format-actions actions)))
          ;; (put ',name 'function-documentation
          ;;      "Performs completions with `ivy-read'.")
          (ivy-configure ',name
            :display-transformer-fn ,(plist-get arg-list :display-fn)
            ,@(defun-ivy-super-get-props
                '(:exit-codes
                  :grep-p
                  :more-chars
                  :format-fn
                  :sort-fn
                  :index-fn
                  :unwind-fn
                  :update-fn
                  :occur
                  :height)
                arg-list))
          (when ,(plist-get arg-list :bind)
            (global-set-key (kbd ,(plist-get arg-list :bind)) ',name))))

(put 'defun-ivy+ 'lisp-indent-function 'defun)
(put 'defun-ivy-read 'lisp-indent-function 'defun)
(provide 'defun-ivy+)
;;; defun-ivy+.el ends here
