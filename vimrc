"""""""""""""""""""
"  .vimrc Config  "
" evilrobotslayer "
"""""""""""""""""""

""""""""""""""""""
" General Config "
""""""""""""""""""
set nocompatible                        " be iMproved, required
set encoding=utf8                       " Set default file encoding
scriptencoding utf-8
set ffs=unix,dos,mac                    " Set default file formats to try
set t_Co=256                            " Set 256 Colors
set history=700                         " Sets how many lines of history VIM has to remember
set autoread                            " Set to auto read when a file is changed from the outside
set magic                               " For regular expressions turn magic on
set showmatch                           " Show matching brackets when text indicator is over them
set mat=2                               " How many tenths of a second to blink when matching brackets
set wildmenu                            " Turn on the WiLd menu
set wildignore=*.o,*~,*.pyc             " Ignore compiled files
set lazyredraw                          " Don't redraw while executing macros (good performance config)
set ttyfast                             " Indicates a fast terminal connection
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<         " Assign characters for whitespace
" Newer versions of VIM ( >= 7.4.710) can also show spaces
if has("patch-7.4.710")
    " The backslash is required before the space if using a literal space character
    set listchars+=space:␣
endif

" Custom Key Mappings "
 """""""""""""""""""""
" These likely are highly dependent on your terminal
"set <S-F1>=O1;2P
set <S-F1>=[1;2P
set <S-F2>=[1;2Q
set <S-F3>=[1;2R
set <S-F4>=[1;2S

" Disable Error Bells "
 """""""""""""""""""""
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Indent Config "
 """""""""""""""
set autoindent                   " Enable autoindent
set nosmartindent                " Don't mess with indentation
filetype plugin indent on        " Use filetype based indentation

" Tab/Space Config "
 """"""""""""
set nosmarttab                   " Don't Use smarttab
set expandtab                    " Use spaces instead of tabs
set shiftwidth=4                 " Set indent size
set softtabstop=4                " Set <tab> input to 4 spaces
autocmd BufWritePre * %s/\s\+$//e " Automatically strip trailing whitespace on save

" Search Config "
 """""""""""""""
set hlsearch                     " Highlight search results
set ignorecase                   " Ignore case when searching
set smartcase                    " When searching try to be smart about cases
set incsearch                    " Makes search act like search in modern browsers

" Layout Config "
 """""""""""""""
set hidden                       " Allow modified buffers to be hidden
set splitbelow                   " Better handling of new splits
set splitright                   " Better handling of new splits

" GUI Config "
 """"""""""""
set mouse=a                                     " Enable mouse support for all modes
"set guifont=DroidSansM\ Nerd\ Font\ 11         " Set Font - Nerd Fonts provides Powerline Icons
set guifont=EnvyCodeR\ Nerd\ Font\ Mono\ 11     " Set Font - Nerd Fonts provides Powerline Icons
" https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/DroidSansMono


""""""""""""""""""""""""
" Plugin Configuration "
""""""""""""""""""""""""

" Auto-install vim-plug "
 """""""""""""""""""""""
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" vim-plug plugin manager "
 """""""""""""""""""""""""
" call plug#begin('~/.vim/plugged')
call plug#begin('~/.vim/bundle')                        " Change default plugin location for compatibility
  Plug 'junegunn/goyo.vim'
  Plug 'junegunn/limelight.vim'
  Plug 'bitc/vim-bad-whitespace'
    autocmd VimEnter * :HideBadWhitespace
  Plug 'vim-python/python-syntax'
  Plug 'vim-scripts/indentpython.vim'

  " NERDTree "
   """"""""""
  " Requires nerd-fonts (DroidSansMono): https://nerdfonts.com/
  Plug 'scrooloose/nerdtree'
    autocmd StdinReadPre * let s:std_in=1               " Start NERDTree if directory or no file specified
    autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif
    autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

    " Quit vim if NERDTree is only window
    autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

    let g:NERDTreeMouseMode = 2                         " Single click expands directories, double click opens files
    " let NERDTreeShowHidden = 1                        " Show hidden files by default
    let NERDTreeSortHiddenFirst = 1                     " Sort hidden files first - like `ls`
    let NERDTreeHighlightCursorline = 1                 " Highlight current cursor line
    let NERDTreeIgnore = ['\.pyc$', '\~$']              " Ignore files in NERDTree
    map <silent> <C-\> :NERDTreeToggle<CR>
  Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
  Plug 'Xuyuanp/nerdtree-git-plugin'
  Plug 'ryanoasis/vim-devicons'
    let g:WebDevIconsUnicodeDecorateFolderNodes = 1
    let g:DevIconsEnableFoldersOpenClose = 1

  " Airline Status Bar "
   """"""""""""""""""""
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
    let g:airline_powerline_fonts = 1                   " Enable Powerline fonts
    let g:airline#extensions#tabline#enabled = 1        " Enable tab line
    let g:airline#extensions#whitespace#enabled = 0     " Disable whitespace plugin
    let g:airline_detect_modified = 1                   " Detect when buffer modified
    let g:airline_detect_paste = 1                      " Detect paste
    let g:airline_detect_crypt = 1                      " Detect crypto
    let g:airline_exclude_preview = 0                   " Exclude preview window from statusline
    let g:airline_theme='onedark'
    let g:airline_solarized_bg='dark'
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-rhubarb'
  Plug 'airblade/vim-gitgutter'

  " Language Specific Plugins "
   """""""""""""""""""""""""""
  Plug 'chase/vim-ansible-yaml'

  " quickr-cscope "
   """""""""""""""
  " https://github.com/ronakg/quickr-cscope.vim
  " \s : Search for all symbol occurances of word under the cursor
  " \g : Search for global definition of the word under the cursor
  " \c : Search for all callers of the function name under the cursor
  " \f : Search for all files matching filename under the cursor
  " \i : Search for all files including filename under the cursor
  " \t : Search for text matching word under the cursor/visualy selected text
  " \e : Enter an egrep patter for searching
  " \d : Search all the functions called by funtion name under the cursor
  " C-o: Return to previous position
  Plug 'ronakg/quickr-cscope.vim'

  " QuickFix-Reflector "
   """"""""""""""""""""
  " https://github.com/stefandtw/quickfix-reflector.vim
  Plug 'stefandtw/quickfix-reflector.vim'

  " Syntax Checking "
   """""""""""""""""
  " Plug 'vim-syntastic/syntastic'

  " YouCompleteMe - Code Completion "
   """""""""""""""""""""""""""""""""
  " Plug 'Valloric/YouCompleteMe'

  " vim-dispatch "
   """"""""""""""
  " https://github.com/tpope/vim-dispatch/blob/master/doc/dispatch.txt
  Plug 'tpope/vim-dispatch'

  " vimpager "
   """"""""""
  " Install directory ~/.vim/bundle/vimpager/vimpager
  " `make install` or `make install-deb` after install
  Plug 'rkitover/vimpager'
   autocmd FileType ansible let b:dispatch = 'ansible-playbook -clocal %'       " Configure ansible handler

  " Color Schemes "
   """""""""""""""
  " Plug 'junegunn/seoul256.vim'
  " Plug 'flazz/vim-colorschemes'
  Plug 'evilrobotslayer/vim-colors-evilrobot'
call plug#end()


""""""""""""""""
" Color Config "
""""""""""""""""
colorscheme evilrobot


""""""""""""""""""""""""""
"  Functional Shortcuts  "
""""""""""""""""""""""""""

" Command & Mode Setting "
"     <F1> - <F4>        "
 """"""""""""""""""""""""
" Set window read-only / Convert line endings / Enable paste mode / Toggle autoindent
nnoremap <silent> <F1> :update<CR>
nnoremap <silent> <S-F1> :vsplit <bar> view ~/.vimrc<CR>
nnoremap <silent> <F2> :set readonly! <bar> :set readonly?<CR>
nnoremap <silent> <F3> :setlocal ff=unix <bar> :update<CR>
nnoremap <silent> <S-F3> :s//\r/g<CR>
set pastetoggle=<F4>
nnoremap <silent> <S-F4> :set autoindent! <bar> :set autoindent?<CR>


" Display and Formatting "
"     <F5> - <F8>        "
 """"""""""""""""""""""""
" Toggle line numbers / Bad Whitespace / Clear highlighting
" Show invisible whitespace and trailing chars
nnoremap <silent> <F5> :set number! <bar> set number?<CR>
nnoremap <silent> <C-F5> :call JumpToLine()<CR>
nnoremap <silent> <S-F5> :set hls! <bar> set hls?<CR>
nnoremap <silent> <F6> :set list! <bar> set list?<CR>
nnoremap <silent> <S-F6> :ToggleBadWhitespace<CR>

" Limelight Highlighting on/off
nnoremap <silent> <F7> :Limelight<CR>
nnoremap <silent> <S-F7> :Limelight!<CR>

" Set scrollbind and diffthis on window / Turn off diff
nnoremap <silent> <F8> :set scb! <bar> :set scb?<CR>
nnoremap <silent> <C-F8> :diffthis<CR>
nnoremap <silent> <S-F8> :diffoff<CR>


" Build Commands "
"  <F9> - <F10   "
 """"""""""""""""
" Dispatch - Asynchronously run build tasks in background
nnoremap <F9> :Dispatch<CR>


" Buffering & Windowing "
"     <F11> - <F12>     "
 """""""""""""""""""""""
" All windows equal size / Close all windows except current / Close current window
nnoremap <silent> <S-F11> <C-w>=
nnoremap <silent> <A-F11> :only<CR>
nnoremap <silent> <C-F11> <C-w>q

" Buffer menu / Next buffer / Previous buffer
nnoremap <silent> <A-F12> :buffers<CR>:buffer<Space>
nnoremap <silent> <F12> :bn<CR>
nnoremap <silent> <S-F12> :bp<CR>


" Map Windowing Controls "
 """"""""""""""""""""""""
" Navigate windows with direction keys
nnoremap <silent> <C-Left> <c-w>h
nnoremap <silent> <C-Right> <c-w>l
nnoremap <silent> <C-Up> <c-w>k
nnoremap <silent> <C-Down> <c-w>j

" Move current window to L/R @ full height or T/B @ full width
nnoremap <silent> [ <C-w>H
nnoremap <silent> ] <C-w>L
nnoremap <silent> + <C-w>K
nnoremap <silent> - <C-w>J

" Rotate windows with bracket keys
nnoremap <silent> < <C-w>R
nnoremap <silent> > <C-w>r

" Resize windows with direction keys
nnoremap <silent> <S-Up> <C-w>-<C-w>-
nnoremap <silent> <S-Down> <C-w>+<C-w>+
nnoremap <silent> <S-Right> <C-w>><C-w>>
nnoremap <silent> <S-Left> <C-w><<C-w><


" Other Shortcuts "
 """""""""""""""""
" Removes trailing whitespace and clears 'empty' lines of spaces/tabs
"nnoremap <leader>w :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar>:nohl<CR>

" Quick buffer switch with Tab
nnoremap <silent> <Tab> :bn<CR>

" Exit vim if there are no unsaved changes
nnoremap <silent> <C-q> :qa<CR>
" Save all open buffers
nnoremap <silent> <C-w> :wa<CR>

" Copy selection to system clipboard in visual mode
"vnoremap <silent> <C-c> "+y
vnoremap <silent> <C-y> "+y
" Paste from system clipboard in visual mode
"vnoremap <silent> <C-v> "+p
vnoremap <silent> <C-p> "+p

" Copy line to system clipboard in normal mode
"nnoremap <silent> <C-c> "+yy
nnoremap <silent> <C-y> "+yy
" Paste from system clipboard in normal mode
"nnoremap <silent> <C-v> "+p
nnoremap <silent> <C-p> "+p

" Global search & replace visually selected text
" (Probably not reg exp safe -- TODO)
vnoremap <C-f> :call Get_visual_selection() <bar> :let @/=g:vselection<cr>
vnoremap <C-h> :call Get_visual_selection() <bar> :call Replace_visual_selection()<cr>
" https://stackoverflow.com/questions/41238238/how-to-map-vim-visual-mode-to-replace-my-selected-text-parts


""""""""""""""""""""""""""
" Custom Language Config "
""""""""""""""""""""""""""

" Python Formatting "
 """""""""""""""""""
" Optimized Python Settings
augroup PythonSettings
    autocmd!
    autocmd FileType python setlocal
        \ tabstop=4
        \ softtabstop=4
        \ shiftwidth=4
        \ textwidth=79
        \ expandtab
        \ autoindent
        \ fileformat=unix
augroup END

" Legacy python settings
"au BufNewFile,BufRead *.py
"    \ set tabstop=4 |
"    \ set softtabstop=4 |
"    \ set shiftwidth=4 |
"    \ set textwidth=119 |
"    \ set expandtab |
"    \ set autoindent |
"    \ set fileformat=unix
"au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/
"autocmd BufRead *.py setlocal colorcolumn=0


""""""""""""""""""""
" Useful Functions "
""""""""""""""""""""

function! Get_visual_selection()
  " Why is this not a built-in Vim script function?!
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][col1 - 1:]
  let g:vselection = join(lines,'\n')
endfunction

function! Replace_visual_selection()
  let change = input(':%s/'.g:vselection.'/: ')
  execute ':%s/'.g:vselection.'/'.change.'/g'
endfunction

function! JumpToLine()
    let l:line = input('Jump to line: ')
    if l:line =~ '^\d\+$'
        execute l:line
    else
        echo " Invalid line number"
    endif
endfunction


""""""""""""""""""
" Misc. Autoruns "
""""""""""""""""""
