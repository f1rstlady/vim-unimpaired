if exists("g:loaded_unimpaired")
  finish
endif
let g:loaded_unimpaired = 1

let s:maps = []
function! s:map(...) abort
  call add(s:maps, copy(a:000))
endfunction

function! s:maps() abort
  for [mode, head, rhs; rest] in s:maps
    let flags = get(rest, 0, '') . (rhs =~# '^<Plug>' ? '' : '<script>')
    let tail = ''
    let keys = get(g:, mode.'remap', {})
    if type(keys) != type({})
      continue
    endif
    while !empty(head) && len(keys)
      if has_key(keys, head)
        let head = keys[head]
        if empty(head)
          let head = '<skip>'
        endif
        break
      endif
      let tail = matchstr(head, '<[^<>]*>$\|.$') . tail
      let head = substitute(head, '<[^<>]*>$\|.$', '', '')
    endwhile
    if head !=# '<skip>' && empty(maparg(head.tail, mode))
      execute mode.'map' flags head.tail rhs
    endif
  endfor
endfunction

" Section: Next and previous

function! s:MapNextFamily(map,cmd) abort
  let map = '<Plug>(Unimpaired'.toupper(a:map)
  let cmd = '".(v:count ? v:count : "")."'.a:cmd
  let end = '"<CR>'.(a:cmd ==# 'l' || a:cmd ==# 'c' ? 'zv' : '')
  execute 'nnoremap <silent> '.map.'Previous) <Cmd>execute "'.cmd.'previous'.end
  execute 'nnoremap <silent> '.map.'Next)     <Cmd>execute "'.cmd.'next'.end
  execute 'nnoremap <silent> '.map.'First)    <Cmd>execute "'.cmd.'first'.end
  execute 'nnoremap <silent> '.map.'Last)     <Cmd>execute "'.cmd.'last'.end
  call s:map('n', '['.        a:map , map.'Previous)')
  call s:map('n', ']'.        a:map , map.'Next)')
  call s:map('n', '['.toupper(a:map), map.'First)')
  call s:map('n', ']'.toupper(a:map), map.'Last)')
  if exists(':'.a:cmd.'nfile')
    execute 'nnoremap <silent> '.map.'PFile) <Cmd>execute "'.cmd.'pfile'.end
    execute 'nnoremap <silent> '.map.'NFile) <Cmd>execute "'.cmd.'nfile'.end
    call s:map('n', '[<C-'.toupper(a:map).'>', map.'PFile)')
    call s:map('n', ']<C-'.toupper(a:map).'>', map.'NFile)')
  elseif exists(':p'.a:cmd.'next')
    execute 'nnoremap <silent> '.map.'PPrevious) <Cmd>execute "p'.cmd.'previous'.end
    execute 'nnoremap <silent> '.map.'PNext) <Cmd>execute "p'.cmd.'next'.end
    call s:map('n', '[<C-'.toupper(a:map).'>', map.'PPrevious)')
    call s:map('n', ']<C-'.toupper(a:map).'>', map.'PNext)')
  endif
endfunction

call s:MapNextFamily('a','')
call s:MapNextFamily('b','b')
call s:MapNextFamily('l','l')
call s:MapNextFamily('q','c')
call s:MapNextFamily('t','t')

function! s:entries(path) abort
  let path = substitute(a:path,'[\\/]$','','')
  let files = split(glob(path."/.*"),"\n")
  let files += split(glob(path."/*"),"\n")
  call map(files,'substitute(v:val,"[\\/]$","","")')
  call filter(files,'v:val !~# "[\\\\/]\\.\\.\\=$"')

  let filter_suffixes = substitute(escape(&suffixes, '~.*$^'), ',', '$\\|', 'g') .'$'
  call filter(files, 'v:val !~# filter_suffixes')

  return files
endfunction

function! s:FileByOffset(num) abort
  let file = expand('%:p')
  if empty(file)
    let file = getcwd() . '/'
  endif
  let num = a:num
  while num
    let files = s:entries(fnamemodify(file,':h'))
    if a:num < 0
      call reverse(sort(filter(files,'v:val <# file')))
    else
      call sort(filter(files,'v:val ># file'))
    endif
    let temp = get(files,0,'')
    if empty(temp)
      let file = fnamemodify(file,':h')
    else
      let file = temp
      let found = 1
      while isdirectory(file)
        let files = s:entries(file)
        if empty(files)
          let found = 0
          break
        endif
        let file = files[num > 0 ? 0 : -1]
      endwhile
      let num += (num > 0 ? -1 : 1) * found
    endif
  endwhile
  return file
endfunction

function! s:fnameescape(file) abort
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

nnoremap <silent> <Plug>(UnimpairedDirectoryNext)     :<C-U>edit <C-R>=<SID>fnameescape(fnamemodify(<SID>FileByOffset(v:count1), ':.'))<CR><CR>
nnoremap <silent> <Plug>(UnimpairedDirectoryPrevious) :<C-U>edit <C-R>=<SID>fnameescape(fnamemodify(<SID>FileByOffset(-v:count1), ':.'))<CR><CR>
call s:map('n', ']f', '<Plug>(UnimpairedDirectoryNext)')
call s:map('n', '[f', '<Plug>(UnimpairedDirectoryPrevious)')

" Section: Diff

call s:map('n', '[n', '<Plug>(UnimpairedContextPrevious)')
call s:map('n', ']n', '<Plug>(UnimpairedContextNext)')
call s:map('x', '[n', '<Plug>(UnimpairedContextPrevious)')
call s:map('x', ']n', '<Plug>(UnimpairedContextNext)')
call s:map('o', '[n', '<Plug>(UnimpairedContextPrevious)')
call s:map('o', ']n', '<Plug>(UnimpairedContextNext)')

nnoremap <silent> <Plug>(UnimpairedContextPrevious) <Cmd>call <SID>Context(1)<CR>
nnoremap <silent> <Plug>(UnimpairedContextNext)     <Cmd>call <SID>Context(0)<CR>
xnoremap <silent> <Plug>(UnimpairedContextPrevious) <Cmd>execute 'normal! gv'<Bar>call <SID>Context(1)<CR>
xnoremap <silent> <Plug>(UnimpairedContextNext)     <Cmd>execute 'normal! gv'<Bar>call <SID>Context(0)<CR>
onoremap <silent> <Plug>(UnimpairedContextPrevious) <Cmd>call <SID>ContextMotion(1)<CR>
onoremap <silent> <Plug>(UnimpairedContextNext)     <Cmd>call <SID>ContextMotion(0)<CR>

function! s:Context(reverse) abort
  call search('^\(@@ .* @@\|[<=>|]\{7}[<=>|]\@!\)', a:reverse ? 'bW' : 'W')
endfunction

function! s:ContextMotion(reverse) abort
  if a:reverse
    -
  endif
  call search('^@@ .* @@\|^diff \|^[<=>|]\{7}[<=>|]\@!', 'bWc')
  if getline('.') =~# '^diff '
    let end = search('^diff ', 'Wn') - 1
    if end < 0
      let end = line('$')
    endif
  elseif getline('.') =~# '^@@ '
    let end = search('^@@ .* @@\|^diff ', 'Wn') - 1
    if end < 0
      let end = line('$')
    endif
  elseif getline('.') =~# '^=\{7\}'
    +
    let end = search('^>\{7}>\@!', 'Wnc')
  elseif getline('.') =~# '^[<=>|]\{7\}'
    let end = search('^[<=>|]\{7}[<=>|]\@!', 'Wn') - 1
  else
    return
  endif
  if end > line('.')
    execute 'normal! V'.(end - line('.')).'j'
  elseif end == line('.')
    normal! V
  endif
endfunction

" Section: Line operations

function! s:BlankUp(count) abort
  put!=repeat(nr2char(10), a:count)
  ']+1
  silent! call repeat#set("\<Plug>(UnimpairedBlankUp)", a:count)
endfunction

function! s:BlankDown(count) abort
  put =repeat(nr2char(10), a:count)
  '[-1
  silent! call repeat#set("\<Plug>(UnimpairedBlankDown)", a:count)
endfunction

nnoremap <silent> <Plug>(UnimpairedBlankUp)   <Cmd>call <SID>BlankUp(v:count1)<CR>
nnoremap <silent> <Plug>(UnimpairedBlankDown) <Cmd>call <SID>BlankDown(v:count1)<CR>

call s:map('n', '[<Space>', '<Plug>(UnimpairedBlankUp)')
call s:map('n', ']<Space>', '<Plug>(UnimpairedBlankDown)')

function! s:ExecMove(cmd) abort
  let old_fdm = &foldmethod
  if old_fdm !=# 'manual'
    let &foldmethod = 'manual'
  endif
  normal! m`
  silent! execute a:cmd
  norm! ``
  if old_fdm !=# 'manual'
    let &foldmethod = old_fdm
  endif
endfunction

function! s:Move(cmd, count, map) abort
  call s:ExecMove('move'.a:cmd.a:count)
  silent! call repeat#set("\<Plug>(UnimpairedMove)".a:map, a:count)
endfunction

function! s:MoveSelectionUp(count) abort
  call s:ExecMove("'<,'>move'<--".a:count)
  silent! call repeat#set("\<Plug>(UnimpairedMoveSelectionUp)", a:count)
endfunction

function! s:MoveSelectionDown(count) abort
  call s:ExecMove("'<,'>move'>+".a:count)
  silent! call repeat#set("\<Plug>(UnimpairedMoveSelectionDown)", a:count)
endfunction

nnoremap <silent> <Plug>(UnimpairedMoveUp)            <Cmd>call <SID>Move('--',v:count1,'Up')<CR>
nnoremap <silent> <Plug>(UnimpairedMoveDown)          <Cmd>call <SID>Move('+',v:count1,'Down')<CR>
noremap  <silent> <Plug>(UnimpairedMoveSelectionUp)   <Cmd>call <SID>MoveSelectionUp(v:count1)<CR>
noremap  <silent> <Plug>(UnimpairedMoveSelectionDown) <Cmd>call <SID>MoveSelectionDown(v:count1)<CR>

call s:map('n', '[e', '<Plug>(UnimpairedMoveUp)')
call s:map('n', ']e', '<Plug>(UnimpairedMoveDown)')
call s:map('x', '[e', '<Plug>(UnimpairedMoveSelectionUp)')
call s:map('x', ']e', '<Plug>(UnimpairedMoveSelectionDown)')

" Section: Option toggling

function! s:statusbump() abort
  let &l:readonly = &l:readonly
  return ''
endfunction

function! s:toggle(op) abort
  call s:statusbump()
  return eval('&'.a:op) ? 'no'.a:op : a:op
endfunction

function! s:cursor_options() abort
  return &cursorline && &cursorcolumn ? 'nocursorline nocursorcolumn' : 'cursorline cursorcolumn'
endfunction

function! s:option_map(letter, option, mode) abort
  call s:map('n', '[o'.a:letter, ':'.a:mode.' '.a:option.'<C-R>=<SID>statusbump()<CR><CR>')
  call s:map('n', ']o'.a:letter, ':'.a:mode.' no'.a:option.'<C-R>=<SID>statusbump()<CR><CR>')
  call s:map('n', 'yo'.a:letter, ':'.a:mode.' <C-R>=<SID>toggle("'.a:option.'")<CR><CR>')
endfunction

call s:map('n', '[ob', ':set background=light<CR>')
call s:map('n', ']ob', ':set background=dark<CR>')
call s:map('n', 'yob', ':set background=<C-R>=&background == "dark" ? "light" : "dark"<CR><CR>')
call s:option_map('c', 'cursorline', 'setlocal')
call s:option_map('-', 'cursorline', 'setlocal')
call s:option_map('_', 'cursorline', 'setlocal')
call s:option_map('u', 'cursorcolumn', 'setlocal')
call s:option_map('<Bar>', 'cursorcolumn', 'setlocal')
call s:map('n', '[od', ':diffthis<CR>')
call s:map('n', ']od', ':diffoff<CR>')
call s:map('n', 'yod', ':<C-R>=&diff ? "diffoff" : "diffthis"<CR><CR>')
call s:option_map('h', 'hlsearch', 'set')
call s:option_map('i', 'ignorecase', 'set')
call s:option_map('l', 'list', 'setlocal')
call s:option_map('n', 'number', 'setlocal')
call s:option_map('r', 'relativenumber', 'setlocal')
call s:option_map('s', 'spell', 'setlocal')
call s:map('n', '[ot', ':setlocal colorcolumn+=+1<CR>')
call s:map('n', ']ot', ':setlocal colorcolumn-=+1<CR>')
call s:map('n', 'yot', ':setlocal <C-R>=(&colorcolumn =~# '."'".'.*+1\%(\\|,.*\)'."'".') ? "colorcolumn-=+1" : "colorcolumn+=+1"<CR><CR>')
call s:option_map('w', 'wrap', 'setlocal')
call s:map('n', '[ov', ':set virtualedit+=all<CR>')
call s:map('n', ']ov', ':set virtualedit-=all<CR>')
call s:map('n', 'yov', ':set <C-R>=(&virtualedit =~# "all") ? "virtualedit-=all" : "virtualedit+=all"<CR><CR>')
call s:map('n', '[ox', ':set cursorline cursorcolumn<CR>')
call s:map('n', ']ox', ':set nocursorline nocursorcolumn<CR>')
call s:map('n', 'yox', ':set <C-R>=<SID>cursor_options()<CR><CR>')
call s:map('n', '[o+', ':set cursorline cursorcolumn<CR>')
call s:map('n', ']o+', ':set nocursorline nocursorcolumn<CR>')
call s:map('n', 'yo+', ':set <C-R>=<SID>cursor_options()<CR><CR>')

function! s:setup_paste() abort
  let s:paste = &paste
  let s:mouse = &mouse
  set paste
  set mouse=
  augroup unimpaired_paste
    autocmd!
    autocmd InsertLeave *
          \ if exists('s:paste') |
          \   let &paste = s:paste |
          \   let &mouse = s:mouse |
          \   unlet s:paste |
          \   unlet s:mouse |
          \ endif |
          \ autocmd! unimpaired_paste
  augroup END
endfunction

nnoremap <silent> <Plug>(UnimpairedPaste) :call <SID>setup_paste()<CR>

call s:map('n', '[op', ':call <SID>setup_paste()<CR>O', '<silent>')
call s:map('n', ']op', ':call <SID>setup_paste()<CR>o', '<silent>')
call s:map('n', 'yop', ':call <SID>setup_paste()<CR>0C', '<silent>')

" Section: Put

function! s:putline(how, map) abort
  let [body, type] = [getreg(v:register), getregtype(v:register)]
  if type ==# 'V'
    execute 'normal! "'.v:register.a:how
  else
    call setreg(v:register, body, 'l')
    execute 'normal! "'.v:register.a:how
    call setreg(v:register, body, type)
  endif
  silent! call repeat#set("\<Plug>(UnimpairedPut)".a:map)
endfunction

nnoremap <silent> <Plug>(UnimpairedPutAbove) :call <SID>putline('[p', 'Above')<CR>
nnoremap <silent> <Plug>(UnimpairedPutBelow) :call <SID>putline(']p', 'Below')<CR>

call s:map('n', '[p', '<Plug>(UnimpairedPutAbove)')
call s:map('n', ']p', '<Plug>(UnimpairedPutBelow)')
call s:map('n', '[P', '<Plug>(UnimpairedPutAbove)')
call s:map('n', ']P', '<Plug>(UnimpairedPutBelow)')
call s:map('n', '>P', "<Cmd>call <SID>putline(v:count1 . '[p', 'Above')<CR>>']", '<silent>')
call s:map('n', '>p', "<Cmd>call <SID>putline(v:count1 . ']p', 'Below')<CR>>']", '<silent>')
call s:map('n', '<P', "<Cmd>call <SID>putline(v:count1 . '[p', 'Above')<CR><']", '<silent>')
call s:map('n', '<p', "<Cmd>call <SID>putline(v:count1 . ']p', 'Below')<CR><']", '<silent>')
call s:map('n', '=P', "<Cmd>call <SID>putline(v:count1 . '[p', 'Above')<CR>=']", '<silent>')
call s:map('n', '=p', "<Cmd>call <SID>putline(v:count1 . ']p', 'Below')<CR>=']", '<silent>')

" Section: Activation

call s:maps()
