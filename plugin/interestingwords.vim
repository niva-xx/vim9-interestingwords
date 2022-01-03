vim9script
# --------------------------------------------------------------------
# This plugin was inspired and based on Steve Losh's interesting words
# ..vimrc config https://www.youtube.com/watch?v=xZuy4gBghho

# Port in vim9script : NiVa 20211226
# --------------------------------------------------------------------

g:interestingWordsGUIColors  = ['#aeee00', '#ff0000', '#0000ff', '#b88823', '#ffa724', '#ff2c4b']
g:interestingWordsTermColors = ['154', '121', '211', '137', '214', '222']

g:interestingWordsGUIColors  = exists('g:interestingWordsGUIColors')  ? g:interestingWordsGUIColors : InterestingWordsGUIColors
g:interestingWordsTermColors = exists('g:interestingWordsTermColors') ? g:interestingWordsTermColors : InterestingWordsTermColors

var s:hasBuiltColors = 0
var currentWord = ''

var s:interestingWords = []
var s:interestingModes = []
var s:mids = {}
var recentlyUsed = []
var searchFlag: string = ''

def ColorWord(word: string, mode: string): void
  if !(s:hasBuiltColors)
    BuildColors()
  endif

  # gets the lowest unused index
  var n = index(s:interestingWords, 0)
  if (n == -1)
    if !(exists('g:interestingWordsCycleColors') && g:interestingWordsCycleColors)
      echom "InterestingWords: max number of highlight groups reached " .. len(s:interestingWords)
      return
    else
      n = s:recentlyUsed[0]
      UncolorWord(s:interestingWords[n])
    endif
  endif

  var mid = 595129 + n
  s:interestingWords[n] = word
  s:interestingModes[n] = mode
  s:mids[word] = mid

  Apply_color_to_word(n, word, mode, mid)

  MarkRecentlyUsed(n)

enddef

def Apply_color_to_word(n: number, word: string, mode: string, mid: number): void
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
enddef

def s:nearest_group_at_cursor(): string
  var matches: dict<any> = {}
  for l_match_item in getmatches()
    # var l_mids = filter(items(s:mids), 'v:val[1] == l_match_item.id')
    var l_mids = items(s:mids)->filter((_, v) => v[1] == l_match_item.id)
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
enddef

def UncolorWord(word: string): void
  var index = index(s:interestingWords, word)

  if (index > -1)
    var mid = s:mids[word]

    silent! matchdelete(mid)
    s:interestingWords[index] = 0
    unlet s:mids[word]
  endif
enddef

def Getmatch(mid: string): string
  return filter(getmatches(), 'v:val.id==mid')[0]
enddef

def WordNavigation(direction: bool): void
  currentWord = s:nearest_group_at_cursor()

  if (CheckIgnoreCase(currentWord))
    currentWord = tolower(currentWord)
  endif

  if (index(s:interestingWords, currentWord) > -1)
    var index: number = index(s:interestingWords, currentWord)
    var mode: string = s:interestingModes[index]
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
enddef

def GetVisualSelection(): string
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
enddef

export def InterestingWords(mode: string): void
  echomsg 'imported function InterestingWords'
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
  if (index(s:interestingWords, currentWord) == -1)
    ColorWord(currentWord, mode)
  else
    UncolorWord(currentWord)
  endif
enddef


def UncolorAllWords(): void
  for word in InterestingWords
    # check that word is actually a String since '0' is falsy
    if (type(word) == 1)
      UncolorWord(word)
    endif
  endfor
enddef

def RecolorAllWords()
  i = 0
  for word in s:interestingWords
    if (type(word) == 1)
      mode = s:interestingModes[i]
      mid = s:mids[word]
      Apply_color_to_word(i, word, mode, mid)
    endif
    i += 1
  endfor
enddef

# returns true if the ignorecase flag needs to be used
def CheckIgnoreCase(word: string): bool 
  # return false if case sensitive is used
  if (exists('g:interestingWordsCaseSensitive'))
    return !g:interestingWordsCaseSensitive
  endif
  # checks ignorecase
  # and then if smartcase is on, check if the word contains an uppercase char
  return &ignorecase && (!&smartcase || (match(word, '\u') == -1))
enddef

# moves the index to the back of the s:recentlyUsed list
def MarkRecentlyUsed(n: number): void
  var index = index(s:recentlyUsed, n)
  remove(s:recentlyUsed, index)
  add(s:recentlyUsed, n)
enddef

def s:UiMode(): string
  # Stolen from airline's airline#init#gui_mode()
  return ((has('nvim') && exists('$NVIM_TUI_ENABLE_TRUE_COLOR') && !exists("+termguicolors"))
     \ || has('gui_running') || (has("termtruecolor") && &guicolors == 1) || (has("termguicolors") && &termguicolors == 1)) ?
      \ 'gui' : 'cterm'
enddef

# initialise highlight colors from list of GUIColors
# initialise length of InterestingWord list
# initialise s:recentlyUsed list
def BuildColors(): void 
  if (s:hasBuiltColors)
    return
  endif
  var ui = s:UiMode()
  var wordColors = (ui == 'gui') ? g:interestingWordsGUIColors : g:interestingWordsTermColors
  if (exists('g:interestingWordsRandomiseColors') && g:interestingWordsRandomiseColors)
    # fisher-yates shuffle
    var i = len(wordColors) - 1
    while i > 0
      var j = s:Random(i)
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
    add(s:interestingWords, 0)
    add(s:interestingModes, 'n')
    add(s:recentlyUsed, currentIndex - 1)
    currentIndex += 1
  endfor
  s:hasBuiltColors = 1
enddef

# helper function to get random number between 0 and n-1 inclusive
def s:Random(n: number): number
  var timestamp: number = reltimestr(reltime())[ -2 : ]->str2nr()
  return float2nr(floor(n * timestamp / 100))
enddef

if !exists('g:interestingWordsDefaultMappings') || g:interestingWordsDefaultMappings != 0
  g:interestingWordsDefaultMappings = 1
endif

if g:interestingWordsDefaultMappings && !hasmapto('<Plug>InterestingWords')
  nnoremap <silent> <leader>k :InterestingWords('n')<cr>
  vnoremap <silent> <leader>k :InterestingWords('v')<cr>
  nnoremap <silent> <leader>K :UncolorAllWords()<cr>

  nnoremap <silent> n :vim9cmd <SID>WordNavigation(1)<CR>
  nnoremap <silent> N :vim9cmd <SID>WordNavigation(0)<CR>
endif

if g:interestingWordsDefaultMappings
  try
    nnoremap <silent> <unique> <script> <Plug>InterestingWords
          \ :InterestingWords('n')<CR>
    vnoremap <silent> <unique> <script> <Plug>InterestingWords
          \ :InterestingWords('v')<CR>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsClear
          \ :UncolorAllWords()<CR>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsForeward
          \ :WordNavigation(1)<CR>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsBackward
          \ :WordNavigation(0)<CR>
  catch /E227/
  endtry
endif
