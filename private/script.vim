set nobackup nowritebackup noundofile noswapfile viminfo= history=0 noshelltemp secure

function! s:OpenSSLReadPre()
endfunction

function! s:OpenSSLReadPost()
	silent! execute "0,$!openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -base64 -d -k '" . $PASS . "'"
	if v:shell_error
		silent! 0,$y
		silent! undo
		echo "Note that your version of openssl may not have the given cipher engine built-in"
		echo "even though the engine may be documented in the openssl man pages."
		echo "ERROR FROM OPENSSL:"
		echo @"
		echo "COULD NOT DECRYPT"
		return
	endif
	redraw!
endfunction

function! s:OpenSSLWritePre()
	silent! execute "0,$!openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -base64 -k '" . $PASS . "'"
	if v:shell_error
		silent! 0,$y
		silent! undo
		echo "Note that your version of openssl may not have the given cipher engine built in"
		echo "even though the engine may be documented in the openssl man pages."
		echo "ERROR FROM OPENSSL:"
		echo @"
		echo "COULD NOT ENCRYPT"
		return
	endif
endfunction

function! s:OpenSSLWritePost()
	"silent! undo
	"redraw!
endfunction

autocmd BufReadPre,FileReadPre     * call s:OpenSSLReadPre()
autocmd BufReadPost,FileReadPost   * call s:OpenSSLReadPost()
autocmd BufWritePre,FileWritePre   * call s:OpenSSLWritePre()
autocmd BufWritePost,FileWritePost * call s:OpenSSLWritePost()
