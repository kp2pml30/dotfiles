set termguicolors
set nowrap
set nu rnu
set list
set listchars=tab:┆\ ,space:·,nbsp:␣
set tabstop=2
set shiftwidth=2
set noexpandtab

nmap <F2> :w<CR>
imap <F2> <C-O>:w<CR>

noremap <expr> <Home> (col('.') == matchend(getline('.'), '^\s*')+1 ? '0' : '^')
imap <Home> <C-o><Home>

vnoremap > >gv
vnoremap < <gv

let s:i = 1
while s:i < 10
	execute printf('nmap <Space>%i %i<C-w><C-w>', s:i, s:i)
	let s:i += 1
endwhile

set clipboard+=unnamedplus

if system('uname -a') =~ '\<WSL2\>'
	let g:clipboard = {
		\   'name': 'WslClipboard',
		\   'copy': {
		\      '+': '/mnt/c/Windows/system32/clip.exe',
		\      '*': '/mnt/c/Windows/system32/clip.exe',
		\    },
		\   'paste': {
		\      '+': ['/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe', '-NoLogo', '-NoProfile', '-c', '[Console]::Out.Write($(Get-Clipboard\ -Raw).tostring().replace("`r",""))'],
		\      '*': ['/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe', '-NoLogo', '-NoProfile', '-c', '[Console]::Out.Write($(Get-Clipboard\ -Raw).tostring().replace("`r",""))'],
		\   },
		\   'cache_enabled': 0,
	\ }
endif

if exists(':GuiRenderLigatures')
	GuiRenderLigatures 1
endif

if exists(':GuiFont')
	GuiFont FiraCode\ Nerd\ Font
endif

function s:post_load()
	colorscheme tokyonight-night

	if exists(':NERDTreeToggle')
		map <F3> :NERDTreeToggle<CR>
		autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
	endif

	if exists(':BufferGoto')
		let s:i = 1
		while s:i < 10
			execute printf('nmap <Leader>%i :BufferGoto %i<CR>', s:i, s:i)
			let s:i += 1
		endwhile

		nmap <C-Right> :BufferNext<CR>
		nmap <C-Left> :BufferPrevious<CR>
		nmap <C-q> :BufferClose<CR>
	endif

	if exists(':DetectIndent')
		autocmd BufRead * DetectIndent
	endif

	if exists(':CocInfo')
		inoremap <silent><expr> <c-space> coc#refresh()
		inoremap <silent><expr> <TAB>
			\ coc#pum#visible() ? coc#pum#confirm() : "\<Tab>"
		nmap <silent> <Space>ld <Plug>(coc-definition)
		nmap <silent> <Space>lt <Plug>(coc-type-definition)
		nmap <silent> <Space>li <Plug>(coc-implementation)
		nmap <silent> <Space>lr <Plug>(coc-references)
	endif

	if exists(':LeaderGuide')
		nnoremap <silent> <leader> :<c-u>LeaderGuide '\'<CR>
		nnoremap <silent> <Space> :<c-u>LeaderGuide '<Space>'<CR>
		let g:smap = get(g:, 'smap', {})
		" let g:smap['<Space>'] = get(g:smap, '<Space>', {})
		" let g:smap['<Space>'].l = 'language'
		let g:smap.l = {'name' : 'language'}
		call leaderGuide#register_prefix_descriptions("<Space>", "g:smap")
	endif
endfunction

:au VimEnter * call s:post_load()
