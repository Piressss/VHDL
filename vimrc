
set showmatch "mostra caracteres ( { [ quando fechados
set textwidth=150 "largura do texto
set nowrap  "sem wrap (quebra de linha)
set mouse=a "habilita todas as acoes do mouse
set nu "numeracao de linhas
set ts=4 "Seta onde o tab para
set sw=4 "largura do tab
set et "espacos em vez de tab
set laststatus=2 "mostra o path do arquivo aberto
"

"auto identacao de bloco apos usar a tecla <enter>
"im :<CR> :<CR><TAB>  "
set autoindent
set smartindent
set ignorecase
 
"Highlight serch
set hlsearch
nnoremap <CR> :noh<CR><CR>
"set incsearch
highlight Search ctermfg=DarkRed ctermbg=DarkGrey

"'Ctrl+PageUp' pula para próxima aba"
nmap <C-Right> :tabnext<CR>
"'Ctrl+PageDown' volta para aba anterior"
nmap <C-Left> :tabprevious<CR>
"Timestamp"
nmap <F7> :pu=strftime('%c')<CR>
"Save File"
"nmap <C-W> :w<CR>

"PLUGIN INSTALL"
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'gmarik/Vundle.vim'
"VIM-VHDL"
Plugin 'suoto/vim-hdl'
" Add Syntastic plugin here "
Plugin 'scrooloose/syntastic'
call vundle#end()
filetype plugin indent on

" CONFIGURA VIM-VHDL
" Configure the project file
let g:vimhdl_conf_file = '<config/file>'
" Tell Syntastic to use vim-hdl
let g:syntastic_vhdl_checkers = ['vimhdl']

" CONFIGURA SYNTASTIC
" Drop Syntastic settings at the end of the config file "
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
set statusline+=%<%f\    " Filename
set statusline+=%=%l:%c

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
"let g:syntastic_vhdl_checkers = ['vcom', 'vimhdl', 'ghdl']
let g:syntastic_vhdl_checkers = ['vimhdl', 'vcom']
let g:syntastic_vhdl_checkers_args = "-explicit -check_synthesis"
let g:syntastic_aggregate_errors = 1
let g:syntastic_loc_list_height = 5

let g:syntastic_stl_format = "[Syntax:line:%F (%t)]"

