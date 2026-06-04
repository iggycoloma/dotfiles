" Basic Vim Configuration
" Minimal, modern vim config for editing in terminals
"
" `silent!` is sprinkled on every command that depends on +eval, +syntax,
" or +autocmd so this config loads cleanly under vim-tiny (the default
" `vi` on Debian/Ubuntu minimal images and many devcontainers). Tiny
" vim parses but errors on `syntax`, `colorscheme`, `let`, `has()`,
" `autocmd`, `<leader>`, etc.; `silent!` suppresses those errors while
" full vim sees them as no-op modifiers.

" Use Vim settings, rather than Vi settings
set nocompatible

" Enable filetype detection and plugins (no-op under -filetype)
silent! filetype plugin indent on

" Syntax highlighting (no-op under -syntax)
silent! syntax on

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
silent! set termguicolors      " Enable true colors (no-op without +termguicolors)
set background=dark
silent! colorscheme desert     " Default colorscheme (no-op under -eval / missing scheme)

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

" Undo (entire block needs +eval; silent! suppresses if-condition errors)
silent! if has('persistent_undo')
    silent! set undofile
    silent! set undodir=~/.vim/undo
    silent! if !isdirectory(&undodir)
        silent! call mkdir(&undodir, 'p', 0700)
    silent! endif
silent! endif

" Key mappings (need +eval for <leader> resolution)
silent! let mapleader=","

" Quick save
silent! nnoremap <leader>w :w<CR>

" Quick quit
silent! nnoremap <leader>q :q<CR>

" Clear search highlight
silent! nnoremap <leader><space> :nohlsearch<CR>

" Easy window navigation
silent! nnoremap <C-h> <C-w>h
silent! nnoremap <C-j> <C-w>j
silent! nnoremap <C-k> <C-w>k
silent! nnoremap <C-l> <C-w>l

" Move lines up/down
silent! nnoremap <A-j> :m .+1<CR>==
silent! nnoremap <A-k> :m .-2<CR>==
silent! vnoremap <A-j> :m '>+1<CR>gv=gv
silent! vnoremap <A-k> :m '<-2<CR>gv=gv

" Better indenting in visual mode
silent! vnoremap < <gv
silent! vnoremap > >gv

" File type specific settings (need +autocmd)
silent! autocmd FileType yaml,yml setlocal ts=2 sts=2 sw=2 expandtab
silent! autocmd FileType javascript,typescript,json setlocal ts=2 sts=2 sw=2 expandtab
silent! autocmd FileType html,css,scss setlocal ts=2 sts=2 sw=2 expandtab
silent! autocmd FileType python setlocal ts=4 sts=4 sw=4 expandtab
silent! autocmd FileType go setlocal ts=4 sts=4 sw=4 noexpandtab
silent! autocmd FileType markdown setlocal wrap linebreak

" Load local vimrc if it exists (needs +eval for filereadable())
silent! if filereadable(expand("~/.vimrc.local"))
    silent! source ~/.vimrc.local
silent! endif
