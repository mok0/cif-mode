;;
;; cif.el --- emacs lisp file for CIF major mode
;;
;; Copyright (c) 1998-2000 Martyn Winn
;;
;; Author: Martyn Winn <m.d.winn@dl.ac.uk>
;;
;; For licensing purposes this program should be regarded as 
;; `Part i)' software of the CCP4 suite and its use is
;; governed by the licences to be found on the CCP4 site
;; (http://www.dl.ac.uk/CCP/CCP4/main.html).
;;
;; Version 0.1 cobbled together June 1998
;; Version 0.2 April 1999
;; Version 0.3 June 1999
;; Version 0.4 June 2000
;;
;; Can be loaded in several ways:
;;    1) M-x load-file RET ~/cif.el
;;    2) Put the line (load "~/cif.el" t) in the .emacs file
;;
;; N.B. you may need following lines in .emacs to get colours:
;;
;; (global-font-lock-mode t) ;turn on Font Lock mode automatically in all modes
;; (setq font-lock-maximum-size nil) ;no buffer too large!
;;
;; Functionality:
;;   Components of CIF file coloured according to function
;;   Automatic pairing of string delimiters '' "" and ;;
;;   "\e\C-a" jump to beginning of data item, or loop
;;   "\e\C-e" jump to end of data item, or loop
;;   "\e\C-b" move to beginning of cif token (with optional argument)
;;   "\e\C-f" move to end of cif token (with optional argument)
;;   Menu: "New data block (C-c d)" insert new data block
;;   Menu: "New loop_ (C-c l)" insert new loop_
;;   Menu: "Identify item in loop (C-c i)" identify which data item a 
;;                                         loop datum corresponds to.
;;   Menu: "Find item in dictionary (C-c s)" bring up the dictionary entry
;;                                           for a data name.
;;   

(defconst cif-mode-version "version 0.3")

(defvar running-emacs20 (string-match "^2" emacs-version))

(cond (running-emacs20
  (progn
    (defgroup cif nil
       "cif-mode for Emacs"
       :group 'languages)

    (defgroup cif-comment nil
       "Comment-handling variables in cif-mode"
       :prefix "cif-"
       :group 'cif)
  )
))
    
(defvar cif-dict-buffer nil
   "Buffer holding CIF dictionary.")

; Activate cif-mode for file endings .cif

(setq auto-mode-alist (cons '("\\.cif\\'" . cif-mode) auto-mode-alist))

; Identify different components of CIF file
; Important: note inclusion of preceding whitespace

(defvar cif-comment "#.*"
  "Regexp to match comment in cif file.")

(defvar cif-data "[ \t\n]data_[^ \t\n]+"
  "Regexp to match data_ keyword in cif file.")

(defvar cif-save "[ \t\n]save_[^ \t\n]*"
  "Regexp to match save_ keyword in cif file.")

(defvar cif-loop "[ \t\n]loop_"
  "Regexp to match loop_ keyword in cif file.")

(defvar cif-word "[ \t\n][^ \t\n]+"
  "Regexp to general word in cif file.")

(defvar cif-item "[ \t\n]_[^ \t\n]+"
  "Regexp to match item name in cif file.")

(defvar cif-quote "[\'\"]"
  "Regexp to match quote in cif file.")

(defvar cif-semicolon "\n\;"
  "Regexp to match semi-colon used as text delimiter in cif file.")

; Tie components to particular faces
; Can't seem to be able to change standard faces via
;   font-lock or hilit, so set up explicit faces

(cond (running-emacs20
  (progn
    (defvar cif-font-lock-comment-face    'cif-font-lock-comment-face
      "Face name to use for comments.")
    (defvar cif-font-lock-keyword-face    'cif-font-lock-keyword-face
      "Face name to use for keywords.")
    (defvar cif-font-lock-item-face    'cif-font-lock-item-face
      "Face name to use for items.")

    (defface cif-font-lock-comment-face
      '((t (:foreground "Cyan")))
      "Font Lock mode face used to highlight comments."
      :group 'font-lock-highlighting-faces)

    (defface cif-font-lock-keyword-face
      '((t (:foreground "Red")))
      "Font Lock mode face used to highlight keywords."
      :group 'font-lock-highlighting-faces)

    (defface cif-font-lock-item-face
      '((t (:foreground "Yellow")))
      "Font Lock mode face used to highlight items."
      :group 'font-lock-highlighting-faces)
  ))
  (t
  (progn
    (defvar cif-font-lock-comment-face    'font-lock-comment-face
      "Face name to use for comments.")
    (defvar cif-font-lock-keyword-face    'font-lock-keyword-face
      "Face name to use for keywords.")
    (defvar cif-font-lock-item-face    'font-lock-variable-name-face
      "Face name to use for items.")
  ))
)

(defvar cif-font-lock-defaults
  (list (cons cif-comment 'cif-font-lock-comment-face)
   (cons cif-data 'cif-font-lock-keyword-face)
   (cons cif-save 'cif-font-lock-keyword-face)
   (cons cif-loop 'cif-font-lock-keyword-face)
   (cons cif-item 'cif-font-lock-item-face))
  "doc")

; Define keymap for cif-mode
; map contains keybindings, menu-map contains pull-down menu

(defvar cif-mode-map
  (let ((map (make-sparse-keymap))
	(menu-map (make-sparse-keymap "CIF")))
    (define-key map "'" 'skeleton-pair-insert-maybe)
    (define-key map "\"" 'skeleton-pair-insert-maybe)
    (define-key map "\;" 'cif-text-pairing)
    (define-key map "\e\C-a" 'move-to-beginning-of-structure)
    (define-key map "\e\C-e" 'move-to-end-of-structure)
    (define-key map "\e\C-b" 'move-backward-cif-token)
    (define-key map "\e\C-f" 'move-forward-cif-token)
    (define-key map "\C-cs" 'search-dictionary)
    (define-key map "\C-ci" 'report-data-item-name)
    (define-key map "\C-cd" 'create-cif-data-block)
    (define-key map "\C-cl" 'create-cif-loop)
    (define-key map [menu-bar insert] (cons "CIF" menu-map))
    (define-key menu-map [search-dictionary]  
                  '("Find item in dictionary" . search-dictionary))
    (define-key menu-map [report-data-item-name]  
                  '("Identify item in loop" . report-data-item-name))
    (define-key menu-map [create-cif-loop]    
                  '("New loop_" . create-cif-loop))
    (define-key menu-map [create-cif-data-block]    
                  '("New data block" . create-cif-data-block))
    map)
  "Keymap used in cif-mode.")


; Specify cif-mode itself

(defun cif-mode ()
  "Put some documentation here!"
  (interactive)
  (kill-all-local-variables)
  (use-local-map cif-mode-map)

  (setq mode-name "CIF")
  (setq major-mode 'cif-mode)

  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(cif-font-lock-defaults t))

  (make-local-variable 'skeleton-pair)
  (setq skeleton-pair t)
  (make-local-variable 'skeleton-pair-alist)
  (setq skeleton-pair-alist '((?' _ ?')
                              (?\" _ ?\")
                              (?\; _ ?\;))))

; Define statement skeletons

(define-skeleton cif-text-pairing
  "Insert text between semi-colons."
  nil "\n\; " _ "\n\;")

(define-skeleton create-cif-loop
  "Create a new loop_"
  nil "\n loop_ \n")

(define-skeleton create-cif-data-block
  "Create a new data block"
  "Name of new data block: " "\ndata_" str "\n\n" _ )

; search- functions

(defun search-dictionary ()
  "Search dictionary for category/item."
  (interactive)
  (setq itemname (query-current-item-name))  
  (cond (itemname
    (progn
      (setq itemname (concat "save_" (substring itemname 1) ) ) 
      (setq beg-buffer (current-buffer)) 
      (switch-to-cif-buffer)
      (setq beg (point))  
      (if (not (re-search-forward itemname nil 'move))
        (if (not (re-search-backward itemname nil 'move))
          (progn
            (goto-char beg) 
            (switch-to-buffer beg-buffer)
            (message "Item name %s not found in dictionary." 
                     (substring itemname 5)) 
          ) 
        )
      ) 
    ))
  ) 
)

; buffer functions

(defun switch-to-cif-buffer ()
  "Switch to buffer holding CIF dictionary. Open dictionary file if necessary."
  (interactive)
  (if (buffer-live-p cif-dict-buffer)
    (switch-to-buffer cif-dict-buffer)
    (progn
      (setq cif-dict-buffer (find-file (read-input "Dictionary file: ")))
      (cif-mode)
    )
  )
)

; report- functions. Generally write messages to bottom line

(defun report-if-cif-loop ()
  "Report whether within loop or not."
  (interactive)
  (if (query-in-cif-loop)
    (message "Cursor is in loop.")
    (message "Cursor not in loop.")))

(defun report-number-loop-items ()
  "Report number of data items within loop."
  (interactive)
  (if (not (query-in-cif-loop))
    (message "Cursor is not in a loop.")
    (message "Number of data items in loop: %d" (count-items-in-cif-loop))))

(defun report-data-item-name ()
  "Identify data item corresponding to value cursor is on."
  (interactive)
  (if (not (query-in-cif-loop))
    (message "Cursor is not in a loop.")
    (setq count (count-values-in-cif-loop))
    (if (<= count 0)
      (message "Cursor is not in the body of the loop.")
      (progn
        (setq count (1- count))
        (setq count (mod count (count-items-in-cif-loop)))
        (setq count (1+ count))
        (message "Item name: %s" (substring (query-loop-item-name count) 2)))
    )
  )
)

; move-to- functions. For moving cursor about file.
; Note that these are highly dependent on the component definitions
; at the top of the file. Also, all the forward and backward movements
; _are_ necessary to get correct behaviour in all cases.

(defun move-backward-cif-token (&optional n)
  "Moves cursor to the beginning of the n'th cif token before the next
   one, which may be a text string delimited by quotes or semi-colon."
  (interactive "P")
  (setq arg (prefix-numeric-value n))
  (move-forward-cif-token (- arg)))   ; call forward function with negative argument

(defun move-backward-one-cif-token ()
  "Moves cursor to the beginning of the current cif token, which may
   be a text string delimited by quotes or semi-colon. If the cursor
   is already at the beginning, move to the previous cif token."
  (re-search-backward cif-word)  
  (if (looking-at cif-semicolon)   
    (progn
      (re-search-backward cif-semicolon)   ; move to matching semicolon
      (forward-char 1)) 
    (progn
      (backward-char 1)  
      (re-search-forward cif-word)
      (backward-char 1)    ; should now be on last character of current or previous word.
      (if (looking-at cif-quote)        ; word ends with a quote
        (progn
          (setq cif-quote-char (char-after (point)))
          (backward-char 1)
          (while (not (looking-at (char-to-string cif-quote-char)))
            (backward-char 1)))
        (progn
          (forward-char 1)
          (re-search-backward cif-word)  
          (forward-char 1))))))

(defun move-forward-cif-token (&optional n)
  "Moves cursor to the beginning of the n'th cif token after the current
   one, which may be a text string delimited by quotes or semi-colon."
  (interactive "P")
  (setq arg (prefix-numeric-value n))
  (if (> arg 0)
    (progn                     ; call forward-one if positive
      (setq count 0)
      (while (< count arg)
        (move-forward-one-cif-token)
        (setq count (1+ count))))
    (progn                     ; call backward-one if negative
      (setq count 0)
      (while (> count arg)
        (move-backward-one-cif-token)
        (setq count (1- count))))))

(defun move-forward-one-cif-token ()
  "Moves cursor to the beginning of the next cif token, which may
   be a text string delimited by quotes or semi-colon."
  (forward-char 1)  
  (re-search-backward cif-word)  
  (if (looking-at cif-semicolon)        ; current word begins with a semicolon
    (progn
      (forward-char 1)  
      (re-search-forward cif-semicolon))   ; move to matching semicolon
    (progn
      (forward-char 1)  
      (if (looking-at cif-quote)        ; current word begins with a quote
        (progn
          (setq cif-quote-char (char-after (point)))
          (forward-char 1)
          (while (not (looking-at (char-to-string cif-quote-char)))
            (forward-char 1))
        )
      )
    )
  )
  (re-search-forward cif-word)  
  (re-search-backward cif-word)  
  (forward-char 1)  
)

(defun move-to-beginning-of-structure ()
  "Moves cursor to the beginning of the current CIF item or loop."
  (interactive)
  (backward-char 1)           ; if at beginning of loop, want to go back
                              ; to previous item/loop
  (if (query-in-cif-loop)
    (progn
      (forward-char 5)                    ; maybe sitting in loop_ keyword
      (re-search-backward cif-loop)       ; move to beginning of loop_
      (forward-char 1))
    (progn
      (forward-char 2)                    ; maybe sitting in data name
      (re-search-backward cif-item nil 'move) ; move to beginning of item or file
      (if (looking-at cif-item)
        (forward-char 1))                
      (if (query-in-cif-loop)
        (progn
          (re-search-backward cif-loop)       ; move to beginning of loop_
          (forward-char 1))))))

(defun move-to-end-of-structure ()
  "Moves cursor to the end of the current CIF item or loop."
  (interactive)
  (if (query-in-cif-loop)                ; if starting in loop, set point to 
      (move-to-beginning-loop-values))   ; end of last data name
  (re-search-forward cif-item)        ; move to next item 
  (if (query-in-cif-loop)             ; then back-up as appropriate
    (re-search-backward cif-loop)
    (re-search-backward cif-item))
  (forward-char 1))

(defun move-to-beginning-loop-values ()
  "Moves cursor to the beginning of the first data value in a CIF loop."
  (interactive)
  (if (query-in-cif-loop)
    (progn
      (forward-char 5)                    ; maybe sitting in loop_ keyword
      (re-search-backward cif-loop)       ; move to beginning of loop_
      (forward-char 1)                  ; next 3 together - clumsy!
      (re-search-forward cif-word)
      (goto-char (match-beginning 0))     
      (while
        (looking-at cif-item)
        (progn
          (forward-char 1)
          (re-search-forward cif-word)
          (goto-char (match-beginning 0)))))))

; query- functions. For internal use.

(defun query-in-cif-loop ()
  "Returns true if cursor is in CIF loop, and false otherwise.
   Covers most situations, but can still get confused by item names
   in comment sections."
  (let ((case-fold-search t))
   (save-excursion            ; save (point)
    (forward-char 1)             ; necessary if cursor at start of word
    (re-search-backward cif-word nil 'move)  ; move to start of current word 
                                             ; or start of buffer 
    (if (looking-at cif-loop)    ; we were sitting on loop_ keyword
      t
      (progn 
        (if (looking-at cif-item)   ; we were sitting on item name
          (progn                 
            (re-search-backward cif-word nil 'move)
      ;is previous word also cif item or the loop_ keyword?
      ;else the item name was not part of a loop
            (or (looking-at cif-item) (looking-at cif-loop))) 
 ; we were not sitting on loop_ or item name, so search backwards to
 ; see where we are
          (progn
            (re-search-backward cif-item nil 'move)  ; move to previous cif item
            (if (looking-at cif-item)   ; found cif item
              (progn                 
                (re-search-backward cif-word nil 'move)
      ;is previous word also cif item or the loop_ keyword?
      ;else the item name was not part of a loop 
                (or (looking-at cif-item) (looking-at cif-loop)))))))))))
 ;else found beginning of buffer

(defun query-loop-item-name ( arg )
  "Return name of nitem'th data item in current loop."
  (let ((case-fold-search t))
   (save-excursion            ; save (point)
    (re-search-backward cif-loop)  
    (let ((count 0))
      (while
        (< count arg)
        (progn
          (re-search-forward cif-item)
          (setq count (1+ count)))))
    (setq itemname (match-string 0))    
   )
  )
  itemname)

(defun query-current-item-name ()
  "Return name of data item under cursor. Return nil if cursor not
   on a cif-item"
  (let ((case-fold-search t))
   (save-excursion            ; save (point)
    (forward-char 1)             ; necessary if cursor at start of word
    (re-search-backward cif-word)  
    (if (looking-at cif-item)   ;is current word a cif item name?
      (setq itemname (match-string 0))
      (setq itemname nil))
   )       
  )
  itemname)

; count- functions. For counting various components.

(defun count-items-in-cif-loop ()
  "Count number of data items within loop. This assumes you have
   already checked that we are in a loop."
  (let ((case-fold-search t))
   (save-excursion            ; save (point)
    (move-to-beginning-loop-values)
    (setq start (point))
    (re-search-backward cif-loop)  
    (setq count 0)
    (while
      (re-search-forward cif-item start t)
      (setq count (1+ count)))
   )
  )       
  count)  

(defun count-values-in-cif-loop ()
  "Count values in loop up to cursor."
  (let ((case-fold-search t))
   (save-excursion            ; save (point)
    (forward-char 1)  
    (move-backward-cif-token)
    (setq start (point))     ; set bound at beginning of current word.
    (move-to-beginning-loop-values)   ; move to start of values, and count past bound
    (setq count 0)                    ; (bound could be in middle of string)
    (while (<= (point) start)    
      (progn
        (move-forward-cif-token)
        (setq count (1+ count))))
    (if (> count 0)
      (setq count (1- count)))     ; compensate for going past bound
   ))
(message "count = %d" count)
count)  

