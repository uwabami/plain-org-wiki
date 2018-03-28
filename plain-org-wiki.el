;;; plain-org-wiki.el --- Simple jump-to-org-files in a directory package

;; Copyright (C) 2015 Oleh Krehel

;; Author: Oleh Krehel <ohwoeowho@gmail.com>
;;         Youhei SASAKI <uwabami@gfd-dennou.org>
;; Version: 0.1.1
;; Package-Requires: nil
;; Keywords: completion

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Original Ver. https://github.com/abo-abo/plain-org-wiki
;;               and https://github.com/caiorss/org-wiki
;; Modified:
;;  - add ido support.
;;  - org custom type: [[wiki:Index][Index]]
;;  - update ivy, find-file-in-project, helm support.

;;; Code:
(eval-and-compile (require 'cl-lib))

(defgroup plain-org-wiki nil
  "Simple jump-to-org-file package."
  :group 'org
  :prefix "plain-org-wiki-")

(defcustom pow-directory "~/org/wiki/"
  "Directory where files for `plain-org-wiki' are stored."
  :type 'directory)

(defcustom pow-template
  (concat "#+TITLE: %n\n"
          "#+DESCRIPTION:\n"
          "#+KEYWORDS:\n"
          "#+STARTUP:  content\n"
          "\n\n"
          "- [[wiki:index][Index]]\n\n"
          "- Related: \n\n"
          "* %n\n"
          )
  "Default template used to create org-wiki pages/files.
- %n - is replaced by the page name.
- %d - is replaced by current date in the format year-month-day."

  :type 'string
  :group 'org-wiki
  )

(defvar pow-extra-dirs nil
  "List of extra directories in addition to `pow-directory'.")

(defun pow-header ()
  "Insert a header at the top of the file."
  (interactive)
  (save-excursion
    (let*
        ;; replace '%n' by page title
        ((text1 (replace-regexp-in-string
                 "%n"
                 (file-name-base (buffer-file-name)) pow-template))
         ;; Replace %d by current date in the format %Y-%m-%d
         (text2 (replace-regexp-in-string
                 "%d"
                 (format-time-string "%Y-%m-%d")
                 text1
                 )))
      ;; Got to top of file
      (goto-char (point-min))
      (insert text2))))

(defun pow-files-in-dir (dir)
  "Return a list of cons cells for DIR.
Each cons cell is a name and file path."
  (let ((default-directory dir))
    (mapcar
     (lambda (x)
       (cons (file-name-sans-extension x)
             (expand-file-name x)))
     (append
      (file-expand-wildcards "*.org")
      (file-expand-wildcards "*.org.gpg")))))

(defun pow-files ()
  "Return .org files in `pow-directory'."
  (cl-mapcan #'pow-files-in-dir
             (cons pow-directory pow-extra-dirs)))

(defun pow--org-link (path desc backend)
  "Creates an html org-wiki pages when  exporting to html."
  (cl-case backend
    (html (format
           "<a href='%s.html'>%s</a>"
           path
           (or desc path)))))

(defun pow--page->file (pagename)
  "Get the corresponding wiki file (*.org) to the wiki PAGENAME."
  (concat (file-name-as-directory pow-directory)
          pagename
          ".org"
          ))

(defun pow--open-page (pagename)
  "Open or create new a org-wiki page (PAGENAME) by name."
  (let ((pow-file (pow--page->file pagename)))
    (if (not (file-exists-p pow-file))
        ;; Action executed if file doesn't exist.
        (progn (find-file  pow-file)
               ;; Insert header at top of page
               (pow-header)
               ;; Save current page buffer
               (save-buffer)
               )
      ;; open file in writable mode.
      (find-file  pow-file)
      )))

;;; Custom Protocols
(add-hook 'org-mode-hook
          (lambda ()
            ;; Hyperlinks to other org-wiki pages
            ;;
            ;; wiki:<page-name> or [[wiki:<page-name>][<page-name>]]
            (org-add-link-type  "wiki"
                                #'pow--open-page
                                #'pow--org-link )))

;;;###autoload
(defun plain-org-wiki ()
  "Ido interface for plain org wiki"
  (interactive)
  (find-file
   (cdr
    (let ((files (pow-files)))
      (assoc
       (ido-completing-read "Open plain org wiki: "
                            (with-temp-buffer
                              (loop for name in files
                                    collect (format "%s" (car name)))))
       files)))))

(when (locate-library "find-file-in-project")
  (require 'find-file-in-project)
  (defun pow-files-recursive ()
    "Return .org files in `pow-directory' and subdirectories."
    (let ((ffip-project-root pow-directory))
      (delq nil
            (mapcar (lambda (x)
                      (when (equal (file-name-extension (car x)) "org")
                        (file-name-sans-extension (car x))))
                    (ffip-project-search "" nil)))))
  )

(when (locate-library "ivy")
  (require 'ivy)
  (defun pow-find-file (x)
    "Open X as a file with org extension in `pow-directory'."
    (when (consp x)
      (setq x (cdr x)))
    (with-ivy-window
     (if (file-exists-p x)
         (find-file x)
       (if (string-match "org$" x)
           (find-file
            (expand-file-name x pow-directory))
         (find-file
          (expand-file-name
           (format "%s.org" x) pow-directory))))))

  ;;;###autoload
  (defun plain-org-wiki-ivy ()
    "Select an org-file to jump to."
    (interactive)
    (ivy-read "pattern: " (pow-files)
              :action 'pow-find-file))

  (when (locate-library "helm")
    (require 'helm)
    (require 'helm-multi-match)

;;;###autoload
    (defun plain-org-wiki-helm ()
      "Select an org-file to jump to."
      (interactive)
      (helm :sources
            '(((name . "Projects")
               (candidates . pow-files)
               (action . pow-find-file))
              ((name . "Create org-wiki")
               (dummy)
               (action . pow-find-file)))))
    )
  )

(provide 'plain-org-wiki)

;;; plain-org-wiki.el ends here
