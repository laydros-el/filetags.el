;;; filetags.el --- package to manage filetags in filename  -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Max Beutelspacher

;; Author: Max Beutelspacher <max@MACS>
;; Keywords: convenience, files
;; Version: 0.0.1

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
(require 'seq)
(require 'subr-x)
(require 'cl)
(require 'ivy)
(defgroup filetags nil "A helper for managing filetags directly in the filename"
  :group 'applications)
(defcustom filetags-delimiter " -- " "delimiter between filename and tags"
  :group 'filetags)
(defcustom filetags-controlled-vocabulary '()
  "tags that can be added (besides tags which are already there)"
  :group 'filetags)

(defun filetags-extract-filetags (filename)
  "extract the tags from FILENAME remove duplicates and sort them"
  (if (string-match-p (regexp-quote filetags-delimiter)
                      (file-name-sans-extension filename))
      (filetags-sort-and-uniq-tags (split-string (car (reverse (split-string (file-name-sans-extension filename)
                                                                             filetags-delimiter)))
                                                 split-string-default-separators
                                                 t
                                                 split-string-default-separators))
    '()))

(defun filetags-sort-and-uniq-tags (tags)
  "sort TAGS and remove duplicates"
  (sort (cl-remove-duplicates tags :test 'string=)
        'string<))

(defun filetags-extract-filename-without-tags (filename)
  "return filename without tags or delimiter or extension"
  (car (split-string (file-name-sans-extension filename)
                     filetags-delimiter)))

(defun filetags-generate-new-filename (old_filename tags)
  "generates filename with TAGS from OLD_FILENAME"
  (let ((new_filename (filetags-extract-filename-without-tags old_filename))
        (extension (file-name-extension old_filename)))
    (if tags
        (concat new_filename
                filetags-delimiter
                (mapconcat 'identity
                           (filetags-sort-and-uniq-tags tags)
                           " ")
                (if extension ".")
                extension)
      (concat new_filename
              (if extension ".")
              extension))))

(defun filetags-add-tags-to-filename (fullname tags)
  "takes TAGS and appends them uniquely and sorted to the FULLNAME and returns the new filename"
  (let* ((old_tags (filetags-extract-filetags (file-name-nondirectory fullname)))
         (all_tags (filetags-sort-and-uniq-tags (append tags old_tags)))
         (new_file_name (filetags-generate-new-filename (file-name-nondirectory fullname)
                                                        all_tags)))
    (concat (file-name-directory fullname)
            new_file_name)))

(defun filetags-remove-tags (fullname tags)
  "takes TAGS and removes any occurence of these tags from the FULLNAME and returns the new filename"
  (let* ((old_tags (filetags-extract-filetags (file-name-nondirectory fullname)))
         (all_tags (filetags-sort-and-uniq-tags (cl-set-difference old_tags tags :test 'string=)))
         (new_file_name (filetags-generate-new-filename (file-name-nondirectory fullname)
                                                        all_tags)))
    (concat (file-name-directory fullname)
            new_file_name)))

;; (defun dired-add-tags (tagsstring)
;;   (interactive "sEnter Tags space seperated: ")
;;   (if (dired-get-marked-files)
;;       (let ((filenames (dired-get-marked-files))
;;             (tags (split-string tagsstring split-string-default-separators
;;                                 t split-string-default-separators)))
;;         (dolist (filename filenames)
;;           (filetags-add-tags-to-filename filename tags)))
;;     (let ((fullname (dired-get-filename))
;;           (tags (split-string tagsstring split-string-default-separators
;;                               t split-string-default-separators)))
;;       (filetags-add-tags-to-filename fullname tags))))

;; (defun dired-remove-tags (tagsstring)
;;   (interactive "sEnter Tags space seperated: ")
;;   (if (dired-get-marked-files)
;;       (let ((filenames (dired-get-marked-files))
;;             (tags (split-string tagsstring split-string-default-separators
;;                                 t split-string-default-separators)))
;;         (dolist (filename filenames)
;;           (filetags-remove-tags filename tags)))
;;     (let ((fullname (dired-get-filename))
;;           (tags (split-string tagsstring split-string-default-separators
;;                               t split-string-default-separators)))
;;       (filetags-remove-tags fullname tags))))

(defun filetags-update-tags (fullname tags-with-prefix)
  "takes TAGS-WITH—PREFIX and depending on the prefix(+/-) removes
 or adds these tags from the FULLNAME and returns the new filename"
  (let ((tags-to-add (filetags-filter-add-tags tags-with-prefix))
        (tags-to-remove (filetags-filter-remove-tags tags-with-prefix))
        (new-filename))
    (setq new-filename (filetags-add-tags-to-filename fullname tags-to-add))
    (filetags-remove-tags new-filename tags-to-remove)))

(defun filetags-filter-add-tags (tags-with-prefix)
  "filter out the tags out of TAGS-WITH—PREFIX that have the + prefix"
  (mapcar (lambda (str)
            (string-trim-left str "+"))
          (seq-filter (lambda (tag)
                        (s-starts-with? "+" tag))
                      tags-with-prefix)))

(defun filetags-filter-remove-tags (tags-with-prefix)
  "filter out the tags out of TAGS-WITH—PREFIX that have the - prefix"
  (mapcar (lambda (str)
            (string-trim-left str "-"))
          (seq-filter (lambda (tag)
                        (s-starts-with? "-" tag))
                      tags-with-prefix)))

(defun filetags-union (l)
  "returns the sorted and unique union of a list of list of strings"
  (filetags-sort-and-uniq-tags (cond
                                ((null l) nil)
                                ((null (cdr l))
                                 (car l))
                                (t (append (car l)
                                           (filetags-union (cdr l)))))))
;; taken from https://stackoverflow.com/a/31422481
(defun filetags-intersection (l &rest cl-keys)
  "returns the sorted and unique intersection of a list of list of strings"
  (filetags-sort-and-uniq-tags(cond
                               ((null l) nil)
                               ((null (cdr l))
                                (car l))
                               (t (apply 'cl-intersection
                                         (car l)
                                         (apply 'filetags-intersection
                                                (cdr l)
                                                cl-keys)
                                         cl-keys))))




  (defun filetags-accumulate-remove-tags-candidates (filenames)
    "takes a list of FILENAMES and accumulate all tags as candidates for potential removal"
    (filetags-union (mapcar 'filetags-extract-filetags filenames))))

(defun filetags-accumulate-add-tags-candidates (filenames)
  "takes a list of FILENAMES and accumulates all tags which are not in every filename for potential adding"
  (let ((remove-tags (filetags-accumulate-remove-tags-candidates
                      filenames))
        (tags-in-every-file (filetags-intersection (mapcar 'filetags-extract-filetags filenames)
                                                   :test 'string=)))
    (set-difference remove-tags tags-in-every-file
                    :test 'string=)))


(defun filetags-prepend (prefix tags)
  "takes PREFIX and add it to every tag in TAGS"
  (mapcar (lambda (str)
            (concat prefix str))
          tags))

(defun filetags-ivy-get-tag (tags)
  "uses ivy to ask for a tag out of TAGS if ENDPROMT is chosen return nil otherwise return tag"
  (let ((new-tag (ivy-read "Add Tags: "
                           (push "ENDPROMPT" tags))))
    (when (not (string= new-tag "ENDPROMPT"))
      new-tag)))




(provide 'filetags)
;;; filetags.el ends here

