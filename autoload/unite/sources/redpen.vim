let s:source = {
            \ 'name' : 'redpen',
            \ 'description' : 'Show result of redpen',
            \ 'default_kind' : 'jump_list',
            \ 'default_action' : 'open',
            \ 'hooks' : {},
            \ 'action_table' : {},
            \ 'syntax' : 'uniteSource__Redpen',
            \ }

function! unite#sources#redpen#define() abort
    return s:source
endfunction

function! s:source.hooks.on_init(args, context) abort
    if exists('b:unite') && has_key(b:unite, 'prev_bufnr')
        let a:context.source__bufnr = b:unite.prev_bufnr
    else
        let a:context.source__bufnr = bufnr('%')
    endif

    let result = getbufvar(a:context.source__bufnr, 'redpen_errors')
    if type(result) == type('')
        let should_jump = a:context.source__bufnr != bufnr('%')
        if should_jump
            let w = bufwinnr(a:context.source__bufnr)
            execute w . 'wincmd w'
        endif
        let file = expand('%:p')
        let args = a:args != [] ? a:args : [file]
        call redpen#set_current_buffer(redpen#detect_config(file), args)
        if should_jump
            wincmd p
        endif
    endif
endfunction

function! s:source.hooks.on_syntax(args, context) abort
    " TODO
endfunction

function! s:source.gather_candidates(args, context) abort
    return map(copy(getbufvar(a:context.source__bufnr, 'redpen_errors').errors), '{
            \   "word" : v:val.message . " [" . v:val.validator . "]",
            \   "action__buffer_nr" : a:context.source__bufnr,
            \   "action__line" : has_key(v:val, "startPosition") ? v:val.startPosition.lineNum : v:val.lineNum,
            \   "action__col" : has_key(v:val, "startPosition") ? v:val.startPosition.offset : v:val.sentenceStartColumnNum,
            \   "action__redpen_error" : v:val,
            \ }')
endfunction

let s:source.action_table.preview = {
            \   'description' : 'Preview detail of the error',
            \   'is_quit' : 0,
            \ }
function! s:source.action_table.preview.func(candidate) abort
    if get(g:, 'unite_kind_file_vertical_preview', 0)
        let unite_winwidth = winwidth(0)
        noautocmd silent execute 'vertical pedit! __REDPEN_ERROR__'
        wincmd P
        let winwidth = (unite_winwidth + winwidth(0)) / 2
        execute 'wincmd p | vert resize ' . winwidth
    else
        noautocmd silent execute 'pedit! __REDPEN_ERROR__'
    endif

    let unite_winnr = winnr()
    try
        wincmd P
        let e = a:candidate.action__redpen_error
        let buffer = join([
                \   'Error:',
                \   '  ' . e.message,
                \   '',
                \   'Sentence:',
                \   '  ' . matchstr(e.sentence, '^\s*\zs.*'),
                \   '',
                \   'Validator:',
                \   '  ' . e.validator,
                \ ], "\n")
        execute 1
        normal! "_dG
        silent put! =buffer
        setlocal nonumber
        setlocal nolist
        setlocal noswapfile
        setlocal nospell
        setlocal nomodeline
        setlocal nofoldenable
        setlocal foldcolumn=0
        setlocal nomodified

        let nr = bufwinnr(a:candidate.action__buffer_nr)
        echom nr
        if nr != -1
            execute nr . 'wincmd w'
            if has_key(e, 'startPosition')
                call cursor(e.startPosition.lineNum, e.startPosition.offset)
            else
                call cursor(e.lineNum, e.sentenceStartColumnNum)
            endif
        endif
    finally
        execute unite_winnr . 'wincmd w'
    endtry
endfunction