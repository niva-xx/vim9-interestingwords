vim9script
# -NV-Update-Log------------------------------------------------------{{{
# This plugin was inspired and based on Steve Losh's interesting words
# ..vimrc config http//www.youtube.com/watch?v=xZuy4gBghho

# 2022-11-20 : Taking account colour blindless deutenaropia
# 2022-01-07 : Take account of patch http//github.com/vim/vim/releases/tag/v8.2.4019
# 2021-12-26 : Port in vim9script
# --------------------------------------------------------------------}}}
# Some vars--{{{
# https://www.colourblindawareness.org/colour-blindness/types-of-colour-blindness/
var interestingWordsGUIColors_nonDeuteranopian  = [ '#bf7f7f', '#d5d5d5', '#e58900' ]
var interestingWordsGUIColors  = [ '#FDEB1F', '#EED94F', '#E5CD43', '#BFAA25', '#BB9F4D', '#b19233', '#9E7701', '#556aad', '#7687bd', '#99a5cd', '#bbc3de']
var interestingWordsTermColors = [ '154', '121', '211', '137', '214', '222' ]

interestingWordsGUIColors  = exists('g:interestingWordsGUIColors')  ? g:interestingWordsGUIColors  : interestingWordsGUIColors
interestingWordsTermColors = exists('g:interestingWordsTermColors') ? g:interestingWordsTermColors : interestingWordsTermColors


var hasBuiltColors     = 0
var currentWord        = ''

var interestingWords   = []
var interestingModes   = []
var mids               = {}
var recentlyUsed       = []
var searchFlag: string = ''
# --}}}

def ColorWord(word: string, mode: string): void # {{{
  if !(hasBuiltColors)
    BuildColors()
  endif

  # gets the lowest unused index
  var n = index(interestingWords, 0)
  if (n == -1)
    if !(exists('g:interestingWordsCycleColors') && g:interestingWordsCycleColors)
      echom "InterestingWord max number of highlight groups reached " .. len(interestingWords)
      return
    else
      n = recentlyUsed[0]
      UncolorWord(interestingWords[n])
    endif
  endif

  var mid = 595129 + n
  interestingWords[n] = word
  interestingModes[n] = mode
  mids[word] = mid

  Apply_color_to_word(n, word, mode, mid)

  MarkRecentlyUsed(n)

enddef # }}}
def Apply_color_to_word(n: number, word: string, mode: string, mid: number): void # {{{
  var case: string = CheckIgnoreCase(word) ? '\c' : '\C'
  var  pat: string = ''
  if mode == 'v'
    pat = case .. '\V\zs' .. escape(word, '\') .. '\ze'
  else
    pat = case .. '\V\<' .. escape(word, '\') .. '\>'
  endif

  try
    call matchadd('InterestingWord' .. string((n + 1)), pat, 1, mid)
  catch /E801/      # match id already taken.
  endtry
enddef # }}}
def Nearest_group_at_cursor(): string # {{{
  # var matche dict<any> = {}
  for l_match_item in getmatches()
    # var l_mids = filter(items(mids), 'v:val[1] == l_match_item.id')
    var l_mids = items(mids)->filter((_, v) => v[1] == l_match_item.id)
    if len(l_mids) == 0
      continue
    endif
    var word: string = l_mids[0][0]
    var position: number = match(getline('.'), l_match_item.pattern)
    if position > -1
      if col('.') > position && col('.') <= position + len(word)
        return word
      endif
    endif
  endfor
  return ''
enddef # }}}
def UncolorWord(word: string): void # {{{
  var index = index(interestingWords, word)

  if (index > -1)
    var mid = mids[word]

    silent! matchdelete(mid)
    interestingWords[index] = 0
    unlet mids[word]
  endif
enddef # }}}
def Getmatch(mid: string): string # {{{
  return filter(getmatches(), 'v:val.id==mid')[0]
enddef # }}}
def WordNavigation(direction: bool): void # {{{
  currentWord = Nearest_group_at_cursor()

  if (CheckIgnoreCase(currentWord))
    currentWord = tolower(currentWord)
  endif

  if (index(interestingWords, currentWord) > -1)
    var index: number = index(interestingWords, currentWord)
    var mode: string = interestingModes[index]
    var case: string = CheckIgnoreCase(currentWord) ? '\c' : '\C'

    var pat: string = case 
    if mode == 'v'
      pat = pat .. '\V\zs' .. escape(currentWord, '\') .. '\ze'
    else
      pat = pat .. '\V\<' .. escape(currentWord, '\') .. '\>'
    endif
    if !(direction)
      searchFlag = 'b'
    endif
    search(pat, searchFlag)
  else
    try
      if (direction)
        normal! n
      else
        normal! N
      endif
    catch /E486/
      echohl WarningMsg | echomsg "E486: Pattern not found: " .. @/
    endtry
  endif
enddef # }}}
def GetVisualSelection(): string # {{{
  var lnum1: number = 0
  var lnum2: number = 0
  var col1: number  = 0
  var col2: number  = 0
  # Why is this not a built-in Vim script function?!
  [lnum1, col1] = getpos("'<")[1 : 2]
  [lnum2, col2] = getpos("'>")[1 : 2]
  var lines = getline(lnum1, lnum2)
  lines[-1] = lines[-1][ : col2 - (&selection == 'inclusive' ? 1 : 2)]
  lines[0] = lines[0][col1 - 1 : ]
  return join(lines, "\n")
enddef # }}}

export def g:InterestingWords(mode: string): void # {{{
  echomsg 'InterestingWords well exported :)'
  if mode == 'v'
    currentWord = GetVisualSelection()
  else
    currentWord = expand('<cword>') .. ''
  endif
  if !(len(currentWord))
    return
  endif
  if (CheckIgnoreCase(currentWord))
    currentWord = tolower(currentWord)
  endif
  if (index(interestingWords, currentWord) == -1)
    ColorWord(currentWord, mode)
  else
    UncolorWord(currentWord)
  endif
enddef # }}}

def g:UncolorAllWords(): void # {{{
  for word in interestingWords
    # check that word is actually a String since '0' is falsy
    if (type(word) == 1)
      UncolorWord(word)
    endif
  endfor
enddef # }}}
def RecolorAllWords() # {{{
  i = 0
  for word in interestingWords
    if (type(word) == 1)
      mode = interestingModes[i]
      mid = mids[word]
      Apply_color_to_word(i, word, mode, mid)
    endif
    i += 1
  endfor
enddef # }}}

def CheckIgnoreCase(word: string): bool  # {{{
  # returns true if the ignorecase flag needs to be used
  # return false if case sensitive is used
  if (exists('g:interestingWordsCaseSensitive'))
    return !g:interestingWordsCaseSensitive
  endif
  # checks ignorecase
  # and then if smartcase is on, check if the word contains an uppercase char
  return &ignorecase && (!&smartcase || (match(word, '\u') == -1))
enddef # }}}
def MarkRecentlyUsed(n: number): void # {{{ moves the index to the back of the recentlyUsed list
  var index = index(recentlyUsed, n)
  remove(recentlyUsed, index)
  add(recentlyUsed, n)
enddef # }}}
def UiMode(): string # {{{
  # Stolen from airline's airline#init#gui_mode()
  return ((has('nvim') && exists('$NVIM_TUI_ENABLE_TRUE_COLOR') && !exists("+termguicolors"))
        \ || has('gui_running') || (has("termtruecolor") && &guicolors == 1) || (has("termguicolors") && &termguicolors == 1)) ?
        \ 'gui' : 'cterm'
enddef # }}}
def BuildColors(): void  # {{{ # initialise highlight colors from list of GUIColors
  # initialise length of InterestingWord list
  # initialise recentlyUsed list
  if (hasBuiltColors)
    return
  endif
  var ui = UiMode()
  var wordColors = (ui == 'gui') ? interestingWordsGUIColors : interestingWordsTermColors
  if (exists('g:interestingWordsRandomiseColors') && g:interestingWordsRandomiseColors)
    # fisher-yates shuffle
    var i = len(wordColors) - 1
    while i > 0
      var j = Random(i)
      var temp = wordColors[i]
      wordColors[i] = wordColors[j]
      wordColors[j] = temp
      i -= 1
    endwhile
  endif
  # select ui type
  # highlight group indexed from 1
  var currentIndex = 1
  for wordColor in wordColors
    execute 'hi! def InterestingWord' .. currentIndex .. ' ' .. ui .. 'bg=' .. wordColor .. ' ' .. ui .. 'fg=Black'
    add(interestingWords, 0)
    add(interestingModes, 'n')
    add(recentlyUsed, currentIndex - 1)
    currentIndex += 1
  endfor
  hasBuiltColors = 1
enddef # }}}
def Random(n: number): number # {{{ helper function to get random number between 0 and n-1 inclusive
  var timestamp: number = reltimestr(reltime())[ -2 : ]->str2nr()
  return float2nr(floor(n * timestamp / 100))
enddef # }}}

# {{{ Mapping
if !exists('g:interestingWordsDefaultMappings') || g:interestingWordsDefaultMappings != 0
  g:interestingWordsDefaultMappings = 1
endif

if g:interestingWordsDefaultMappings && !hasmapto('<Plug>InterestingWords')
  nnoremap <silent> <leader>k :call g:InterestingWords('n')<cr>
  vnoremap <silent> <leader>k :call g:InterestingWords('v')<cr>
  nnoremap <silent> <leader>K :call g:UncolorAllWords()<cr>

  nnoremap <silent> n :vim9cmd <SID>WordNavigation(1)<CR>
  nnoremap <silent> N :vim9cmd <SID>WordNavigation(0)<CR>
endif

if g:interestingWordsDefaultMappings
  try
    nnoremap <silent> <unique> <script> <Plug>InterestingWords
          \ :g:InterestingWords('n')<CR>
    vnoremap <silent> <unique> <script> <Plug>InterestingWords
          \ :g:InterestingWords('v')<CR>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsClear
          \ :g:UncolorAllWords()<CR>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsForeward
          \ :WordNavigation(1)<CR>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsBackward
          \ :WordNavigation(0)<CR>
  catch /E227/
  endtry
endif
# }}}

# vim: set ft=vim ff=dos fdm=marker ts=2 :expandtab:
