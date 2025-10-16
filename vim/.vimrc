" Basic Vim Configuration
" Minimal, modern vim config for editing in terminals

" Use Vim settings, rather than Vi settings
set nocompatible

" Enable filetype detection and plugins
filetype plugin indent on

" Syntax highlighting
syntax on

" General settings
set encoding=utf-8
set fileencoding=utf-8
set backspace=indent,eol,start " Allow backspace in insert mode
set history=1000               " Store more command history
set showcmd                    " Show incomplete cmds down the bottom
set showmode                   " Show current mode
set gcr=a:blinkon0            " Disable cursor blink
set visualbell                 " No sounds
set autoread                   " Reload files changed outside vim
set hidden                     " Allow hidden buffers

" Search settings
set incsearch                  " Find the next match as we type
set hlsearch                   " Highlight searches
set ignorecase                 " Ignore case when searching
set smartcase                  " Unless we type a capital

" Indentation
set autoindent
set smartindent
set smarttab
set shiftwidth=4
set softtabstop=4
set tabstop=4
set expandtab                  " Use spaces instead of tabs

" Display
set number                     " Line numbers
set ruler                      " Show cursor position
set wrap                       " Wrap lines
set linebreak                  " Break lines at word boundaries
set scrolloff=8                " Start scrolling 8 lines before edge
set sidescrolloff=15
set sidescroll=1
set showmatch                  " Show matching brackets
set matchtime=2

" Colors
set termguicolors              " Enable true colors
set background=dark
colorscheme desert             " Default colorscheme

" Status line
set laststatus=2               " Always show status line
set statusline=%F              " Full file path
set statusline+=\ %m           " Modified flag
set statusline+=\ %r           " Read-only flag
set statusline+=%=             " Switch to right side
set statusline+=\ %y           " File type
set statusline+=\ %l:%c        " Line:column
set statusline+=\ %p%%         " Percentage through file

" Wildmenu (command completion)
set wildmenu
set wildmode=longest:full,full
set wildignore=*.o,*~,*.pyc,*/.git/*,*/.hg/*,*/.svn/*,*/node_modules/*

" No swap/backup files
set noswapfile
set nobackup
set nowritebackup

" Undo
if has('persistent_undo')
    set undofile
    set undodir=~/.vim/undo
    if !isdirectory(&undodir)
        call mkdir(&undodir, 'p', 0700)
    endif
endif

" Key mappings
let mapleader=","

" Quick save
nnoremap <leader>w :w<CR>

" Quick quit
nnoremap <leader>q :q<CR>

" Clear search highlight
nnoremap <leader><space> :nohlsearch<CR>

" Easy window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Move lines up/down
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

" Better indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" File type specific settings
autocmd FileType yaml,yml setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType javascript,typescript,json setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType html,css,scss setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType python setlocal ts=4 sts=4 sw=4 expandtab
autocmd FileType go setlocal ts=4 sts=4 sw=4 noexpandtab
autocmd FileType markdown setlocal wrap linebreak

" Load local vimrc if it exists
if filereadable(expand("~/.vimrc.local"))
    source ~/.vimrc.local
endif
