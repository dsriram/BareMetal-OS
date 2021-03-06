; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2013 Return Infinity -- see LICENSE.TXT
;
; BMFS Functions
; =============================================================================

align 16
db 'DEBUG: BMFS     '
align 16


; -----------------------------------------------------------------------------
; init_bmfs -- Initialize the BMFS driver
init_bmfs:
	push rdi
	push rdx
	push rcx
	push rax

	; Read directory to memory
	mov rax, 8			; Start to read from 4K in
	mov rcx, 8			; Read 8 sectors (4KiB)
	xor edx, edx			; Read from drive 0
	mov rdi, bmfs_directory
	call readsectors

	; Get total blocks
	mov eax, [hd1_size]		; in mebibytes (MiB)
	shr rax, 1
	mov [bmfs_TotalBlocks], rax

	pop rax
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_file_open -- Open a file on disk
; IN:	RSI = File name (zero-terminated string)
; OUT:	RAX = File I/O handler, 0 on error
;	All other registers preserved
os_bmfs_file_open:
	push rsi
	push rdx
	push rcx
	push rbx

	; Query the existance
	call os_bmfs_file_query
	jc os_bmfs_file_open_error
	mov rax, rbx			; Slot #
	add rax, 10			; Files start at 10

	; Is it already open? If not, mark as open
	mov rsi, os_filehandlers
	add rsi, rbx
	cmp byte [rsi], 0		; 0 is closed
	jne os_bmfs_file_open_error
	mov byte [rsi], 1		; Set to open

	; Reset the seek
	mov rsi, os_filehandlers_seek
	shl rbx, 3			; Quick multiply by 8
	add rsi, rbx
	xor ebx, ebx			; SEEK_START
	mov qword [rsi], rbx

	jmp os_bmfs_file_open_done

os_bmfs_file_open_error:
	xor eax, eax

os_bmfs_file_open_done:
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_file_close -- Close an open file
; IN:	RAX = File I/O handler
; OUT:	All registers preserved
os_bmfs_file_close:
	push rsi
	push rax

	; Is it in the valid file handler range?
	sub rax, 10			; Subtract the handler offset
	cmp rax, 64			; BMFS has up to 64 files
	jg os_bmfs_file_close_error

	; Mark as closed
	mov rsi, os_filehandlers
	add rsi, rax
	mov byte [rsi], 0		; Set to closed

os_bmfs_file_close_error:

os_bmfs_file_close_done:
	pop rax
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bmfs_file_read -- Read a number of bytes from a file
; IN:	RAX = File I/O handler
;	RCX = Number of bytes to read
;	RDI = Destination memory address
; OUT:	RCX = Number of bytes read
;	All other registers preserved
os_bmfs_file_read:
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	; Is it in the valid file handler range?
	sub rax, 10			; Subtract the handler offset
	cmp rax, 64			; BMFS has up to 64 files
	jg os_bmfs_file_read_error

	; Is this an open file?
	mov rsi, os_filehandlers
	add rsi, rax
	cmp byte [rsi], 0
	je os_bmfs_file_read_error

	; Get the starting sector
	mov rsi, bmfs_directory		; Beginning of directory structure
	shl rax, 6			; Quicky multiply by 64 (size of BMFS record)
	add rsi, rax
	add rsi, 32			; Offset to starting sector
	lodsq				; Load starting sector in RAX

;	add rcx, 511			; Convert byte count to the number of sectors required to fit
;	shr rcx, 9
;	shl rax, 12			; Multiply block start count by 4096 to get sector start count
;	mov rbx, rcx
;	xor edx, edx			; Read from drive 0
;
;os_bmfs_file_read_loop:
;	mov rcx, 4096			; Read 2MiB at a time
;	cmp rbx, rcx
;	jg os_bmfs_file_read_read
;	mov rcx, rbx
;
;os_bmfs_file_read_read:
;	call readsectors
;	sub rbx, rcx
;	jnz os_bmfs_file_read_loop
;	jmp os_bmfs_file_read_done

os_bmfs_file_read_error:
	xor ecx, ecx

os_bmfs_file_read_done:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bmfs_file_write -- Write a number of bytes to a file
; IN:	RAX = File I/O handler
;	RCX = Number of bytes to write
;	RSI = Source memory address
; OUT:	RCX = Number of bytes written
;	All other registers preserved
os_bmfs_file_write:
	; Is this an open file?


	; Flush directory to disk

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bmfs_file_seek -- Seek to position in a file
; IN:	RAX = File I/O handler
;	RCX = Number of bytes to offset from origin.
;	RDX = Origin
; OUT:	All registers preserved
os_bmfs_file_seek:
	; Is this an open file?

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bmfs_file_query -- Search for a file name and return information
; IN:	RSI = Pointer to file name
; OUT:	RAX = Staring block number
;	RBX = Offset to entry
;	RCX = File size in bytes
;	RDX = Reserved blocks
;	Carry set if not found. If carry is set then ignore returned values
os_bmfs_file_query:
	push rdi

	clc				; Clear carry
	mov rdi, bmfs_directory		; Beginning of directory structure

os_bmfs_file_query_next:
	call os_string_compare
	jc os_bmfs_file_query_found
	add rdi, 64			; Next record
	cmp rdi, bmfs_directory + 0x1000	; End of directory
	jne os_bmfs_file_query_next
	stc				; Set flag for file not found
	pop rdi
	ret

os_bmfs_file_query_found:
	clc				; Clear flag for file found
	mov rbx, rdi
	mov rdx, [rdi + BMFS_DirEnt.reserved]	; Reserved blocks
	mov rcx, [rdi + BMFS_DirEnt.size]	; Size in bytes
	mov rax, [rdi + BMFS_DirEnt.start]	; Starting block number

	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bmfs_file_create -- Create a file on the hard disk
; IN:	RSI = Pointer to file name, must be <= 32 characters
;	RCX = File size to reserve (rounded up to the nearest 2MiB)
; OUT:	Carry clear on success, set on failure
; Note:	This function pre-allocates all blocks required for the file
os_bmfs_file_create:

	; Flush directory to disk

	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_bmfs_file_delete -- Delete a file from the hard disk
; IN:	RSI = File name to delete
; OUT:	Carry clear on success, set on failure
os_bmfs_file_delete:
	push rdx
	push rcx
	push rbx
	push rax

	call os_bmfs_file_query
	jc os_bmfs_file_delete_notfound

	mov byte [rbx + BMFS_DirEnt.filename], 0x01 ; Add deleted marker to file name

	; Flush directory to disk

os_bmfs_file_delete_notfound:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
