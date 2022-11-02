;;; helm-ctest.el --- Run ctest from within emacs

;; Copyright (C) 2015 Dan LaManna

;; Author: Dan LaManna <me@danlamanna.com>
;; Version: 1.0
;; Keywords: helm,ctest
;; Package-Requires: ((s "1.9.0") (dash "2.11.0") (helm-core "3.6.0"))

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
(require 's)
(require 'dash)
(require 'cl-lib)
(eval-when-compile
  (require 'helm-source nil t))

(declare-function helm "ext:helm")
(declare-function helm-marked-candidates "ext:helm")
(declare-function helm-build-sync-source "ext:helm")

;;; Code:

(defcustom helm-ctest-dir nil
  "Directory to run ctest in."
  :group 'helm-ctest
  :type 'string)

(defcustom helm-ctest-env nil
  "Environment variables for tests."
  :group 'helm-ctest
  :type 'string)

(defcustom helm-ctest-bin "ctest"
  "Ctest execution binary"
  :group 'helm-ctest
  :type 'string
  )

(defcustom helm-ctest-candidates-command (concat helm-ctest-bin " -N")
  "Command used to list the tests."
  :group 'helm-ctest
  :type 'string)

(defcustom helm-ctest-completion-method 'helm
  "Method to select a candidate from a list of strings."
  :type '(choice
          (const :tag "Helm" helm)
          (const :tag "Emacs" emacs)
          (const :tag "Ido" ido)))


(defun helm-ctest-build-dir()
  "Determine the directory to run ctest in, and set it to
  `helm-ctest-dir'.

   Ensures it has a trailing slash."
  (unless helm-ctest-dir
    (setq helm-ctest-dir
          (read-directory-name "CTest Build Dir: ")))
  (s-append "/" (s-chop-suffix "/" helm-ctest-dir)))

(defun helm-ctest-candidates()
  "Run ctest to figure out what test candidates exist."
  (let* ((ctest-cmd helm-ctest-candidates-command)
         (test-re "^Test[[:space:]]*#")
         (default-directory (helm-ctest-build-dir)))
    (-filter (lambda(s)
               (s-match test-re s))
             (-map 's-trim
                   (s-lines (shell-command-to-string ctest-cmd))))))

(defun helm-ctest-nums-from-strs(strs)
  "Takes a list of `strs' with elements like:
   'Test #17: pep8_style_core' and returns a list of numbers
   representing the strings.

   This is useful for turning the selected tests into a ctest command
   using their integer representation."
  (-map (lambda(s)
          (string-to-number
           (car (cdr (s-match "#\\([[:digit:]]+\\)" s)))))
        strs))

(defun helm-ctest-command(test-nums)
  "Create the command that ctest should run based on the selected
   candidates."
  (concat "env CLICOLOR_FORCE=1 CTEST_OUTPUT_ON_FAILURE=1 "
          helm-ctest-env " "
          helm-ctest-bin " -I "
          (s-join "," (-map (lambda(test-num)
                              (format "%d,%d," test-num test-num))
                            test-nums))))

(defun helm-ctest-action(targets)
  "The action to run ctest on the selected tests.
   Uses the compile interface."
  (let* ((test-strs (if (eq helm-make-completion-method 'helm)
                      (helm-marked-candidates)
                      targets))
         (test-nums (helm-ctest-nums-from-strs test-strs))
         (default-directory (helm-ctest-build-dir))
         (compile-command (helm-ctest-command test-nums)))
    (compile compile-command)))

;;;###autoload
(defun helm-ctest()
  (interactive)
  (let ((candidates (helm-ctest-candidates)))
    (cl-case helm-make-completion-method
      (helm
       (require 'helm)
       (helm :sources (helm-build-sync-source "CTests"
                        :candidates candidates
                        :action '(("run tests" . helm-ctest-action)))
             :buffer "*helm ctest*"))
      (emacs
       (let ((targets (completing-read-multiple
                      "CTests: " candidates nil t)))
         (when targets
           (helm-ctest-action targets))))
      (ido
       (let ((target (ido-completing-read
                      "CTests: " candidates)))
         (when target
           (helm-ctest-action (list target))))))))

(provide 'helm-ctest)
;;; helm-ctest.el ends here
