set nobackup nowritebackup noundofile noswapfile noshelltemp secure
set viminfo= shada= history=0

silent echom "[pass] init sourced; PASS_DECRYPT_CMD=" . $PASS_DECRYPT_CMD
silent echom "[pass] PASS_ENCRYPT_CMD=" . $PASS_ENCRYPT_CMD

function! s:Decrypt() abort
  silent echom "[pass] Decrypt fired for " . expand("<afile>")
  silent execute "0,$!" . $PASS_DECRYPT_CMD
  silent echom "[pass] Decrypt shell_error=" . v:shell_error
  if v:shell_error
    echohl ErrorMsg | echom "age decrypt failed" | echohl None
    cquit!
  endif
  setlocal nomodified
endfunction

function! s:Encrypt() abort
  silent echom "[pass] Encrypt fired for " . expand("<afile>")
  silent execute "0,$!" . $PASS_ENCRYPT_CMD
  silent echom "[pass] Encrypt shell_error=" . v:shell_error
  if v:shell_error
    echohl ErrorMsg | echom "age encrypt failed" | echohl None
  endif
endfunction

function! s:EncryptPost() abort
  silent echom "[pass] EncryptPost fired"
  silent! undo
  setlocal nomodified
endfunction

autocmd BufNewFile                 * silent echom "[pass] BufNewFile " . expand("<afile>")
autocmd BufReadPost,FileReadPost   * call s:Decrypt()
autocmd BufWritePre,FileWritePre   * call s:Encrypt()
autocmd BufWritePost,FileWritePost * call s:EncryptPost()
