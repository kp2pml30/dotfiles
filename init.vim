call plug#begin()
	# Plug 'nvim-tree/nvim-tree.lua'
	Plug 'preservim/nerdtree'
	Plug 'kyazdani42/nvim-web-devicons'
	Plug 'romgrk/barbar.nvim'
	Plug 'lukas-reineke/indent-blankline.nvim'
	Plug 'm4xshen/autoclose.nvim'
	Plug 'neoclide/coc.nvim', {'branch': 'release'}
	Plug 'spinks/vim-leader-guide'
	Plug 'feline-nvim/feline.nvim'
	Plug 'folke/tokyonight.nvim', { 'branch': 'main' }
call plug#end()

set termguicolors
colorscheme tokyonight-night
if exists(':GuiRenderLigatures')
	GuiRenderLigatures 1
endif

set nowrap

set clipboard=unnamedplus

set nu rnu
set list
set listchars=tab:┆\ ,space:·,nbsp:␣
set tabstop=2
set shiftwidth=2
set noexpandtab

nmap <F2> :w<CR>
imap <F2> <C-O>:w<CR>
nmap <F3> :NERDTreeToggle<CR>
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
noremap <expr> <Home> (col('.') == matchend(getline('.'), '^\s*')+1 ? '0' : '^')
imap <Home> <C-o><Home>

let s:i = 1
while s:i < 10
	execute printf('nmap <Leader>%i :BufferGoto %i<CR>', s:i, s:i)
	execute printf('nmap <Space>%i %i<C-w><C-w>', s:i, s:i)
	let s:i += 1
endwhile

nmap <C-Right> :BufferNext<CR>
nmap <C-Left> :BufferPrevious<CR>
nmap <C-q> :BufferClose<CR>

vnoremap > >gv
vnoremap < <gv

inoremap <silent><expr> <c-space> coc#refresh()
inoremap <silent><expr> <TAB>
	\ coc#pum#visible() ? coc#pum#confirm() : "\<Tab>"
nmap <silent> <Space>ld <Plug>(coc-definition)
nmap <silent> <Space>lt <Plug>(coc-type-definition)
nmap <silent> <Space>li <Plug>(coc-implementation)
nmap <silent> <Space>lr <Plug>(coc-references)

nnoremap <silent> <leader> :<c-u>LeaderGuide '\'<CR>
nnoremap <silent> <Space> :<c-u>LeaderGuide '<Space>'<CR>
let g:smap = get(g:, 'smap', {})
" let g:smap['<Space>'] = get(g:smap, '<Space>', {})
" let g:smap['<Space>'].l = 'language'
let g:smap.l = {'name' : 'language'}
call leaderGuide#register_prefix_descriptions("<Space>", "g:smap")

au BufReadPost *.ets set syntax=typescript

lua require("feline").setup()
lua require("ibl").setup()
lua require("autoclose").setup()
lua require("nvim-tree").setup()
