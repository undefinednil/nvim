let mapleader = " "

syntax on
set background=dark
set number
set relativenumber
set ignorecase
set smartcase
set hlsearch
set incsearch
set scrolloff=10
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set smarttab
set smartindent
set nowrap
set noswapfile
set nobackup
set undofile
" separate undo dirs per editor: vim cannot read neovim's undo files (and vice versa)
if !has('nvim')
  set undodir=$HOME/.vim/undo
endif
set updatetime=50
set clipboard=
set mouse=

" sane clipboard
nnoremap c "_c
nnoremap C "_C
nnoremap x "_x
xnoremap x "_x
nnoremap X "+x
xnoremap X "+x
nnoremap d "_d
xnoremap d "_d
nnoremap D "_D
nnoremap <leader>d "+dd
nnoremap <leader>D "+D
nnoremap p "+p
xnoremap p "_d"+P
nnoremap P "+P
xnoremap P "_d"+P
nnoremap y "+y
noremap <leader>y y
noremap <leader>p p
" yank without jump
xnoremap y "+ygv<esc>
" redo
nnoremap U <C-r>
" no highlight
nnoremap Q :noh<CR>
" sane scroll
nnoremap <C-u> Hzz
nnoremap <C-d> Lzz
noremap H ^
noremap L $
" visual block
nnoremap <leader>v <C-v>
" search and replace
nnoremap <leader>ss /<C-r>+<CR>
xnoremap <leader>ss "zy/<C-r>z<CR>
nnoremap <leader>sr :%s/<C-r>+/<C-r>+/gc<left><left><left>
xnoremap <leader>sr "zy:%s/<C-r>z/<C-r>z/gc<left><left><left>
" sudo write
nnoremap <leader>sw :w !sudo tee > /dev/null %<CR>
" set paste
nnoremap <leader>sp :set paste<CR>
" set copy
nnoremap <leader>sc :set nonumber norelativenumber signcolumn=no wrap<CR>
" ctrl-s save
noremap <silent> <C-S> :update<CR>
vnoremap <silent> <C-S> <C-C>:update<CR>
inoremap <silent> <C-S> <C-O>:update<CR>
" simple motion
map s <leader><leader>w
map S <leader><leader>b
