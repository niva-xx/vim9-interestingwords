vim9script
# --------------------------------------------------------------------
# This plugin was inspired and based on Steve Losh's interesting words
# ..vimrc config https://www.youtube.com/watch?v=xZuy4gBghho

# Port in vim9script : NiVa 20211226
# --------------------------------------------------------------------

var interestingWordsGUIColors = ['#aeee00', '#ff0000', '#0000ff', '#b88823', '#ffa724', '#ff2c4b']
var interestingWordsTermColors = ['154', '121', '211', '137', '214', '222']

interestingWordsGUIColors = exists('g:interestingWordsGUIColors') ? g:interestingWordsGUIColors : InterestingWordsGUIColors
interestingWordsTermColors = exists('g:interestingWordsTermColors') ? g:interestingWordsTermColors : InterestingWordsTermColors

var hasBuiltColors = 0

var interestingWords = []
var interestingModes = []
var mids = {}
var recentlyUsed = []

def ColorWord(word: string, mode: string): void
  if !(HasBuiltColors)
    BuildColors()
  endif

  # gets the lowest unused index
  n = index(InterestingWords, 0)
  if (n == -1)
    if !(exists('g:interestingWordsCycleColors') && g:interestingWordsCycleColors)
      echom "InterestingWords: max number of highlight groups reached " .. len(InterestingWords)
      return
    else
      n = s:recentlyUsed[0]
      UncolorWord(InterestingWords[n])
    endif
  endif

  mid = 595129 + n
  InterestingWords[n] = word
  InterestingModes[n] = mode
  Mids[word] = mid

  Apply_color_to_word(n, word, mode, mid)

  MarkRecentlyUsed(n)

enddef

def Apply_color_to_word(n: number, word: string, mode: string, mid: string): void
  case = CheckIgnoreCase(word) ? '\c' : '\C'
  if mode == 'v'
    pat = case .. '\V\zs' .. escape(word, '\') .. '\ze'
  else
    pat = case .. '\V\<' .. escape(word, '\') .. '\>'
  endif

  try
    matchadd("InterestingWord" .. (n + 1), pat, 1, mid)
  catch /E801/      " match id already taken.
  endtry
enddef

def s:nearest_group_at_cursor(): string
  l:matches = {}
  for l:match_item in getmatches()
    l:mids = filter(items(Mids), 'v:val[1] == l:match_item.id')
    if len(l:mids) == 0
      continue
    endif
    l:word = l:mids[0][0]
    l:position = match(getline('.'), l:match_item.pattern)
    if l:position > -1
      if col('.') > l:position && col('.') <= l:position + len(l:word)
        return l:word
      endif
    endif
  endfor
  return ''
enddef

def UncolorWord(word: string): void
  index = index(InterestingWords, word)

  if (index > -1)
    mid = Mids[word]

    silent! matchdelete(mid)
    InterestingWords[index] = 0
    unlet Mids[word]
  endif
enddef

def Getmatch(mid: string): string
  return filter(getmatches(), 'v:val.id==mid')[0]
enddef

def WordNavigation(direction: string): void
  currentWord = s:nearest_group_at_cursor()

  if (CheckIgnoreCase(currentWord))
    currentWord = tolower(currentWord)
  endif

  if (index(InterestingWords, currentWord) > -1)
    l:index = index(InterestingWords, currentWord)
    l:mode = InterestingModes[index]
    case = CheckIgnoreCase(currentWord) ? '\c' : '\C'
    if l:mode == 'v'
      pat = case .. '\V\zs' .. escape(currentWord, '\') .. '\ze'
    else
      pat = case .. '\V\<' .. escape(currentWord, '\') .. '\>'
    endif
    searchFlag = ''
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

def InterestingWords(mode: string): void
  if mode == 'v'
    currentWord = Get_visual_selection()
  else
    currentWord = expand('<cword>') .. ''
  endif
  if !(len(currentWord))
    return
  endif
  if (CheckIgnoreCase(currentWord))
    currentWord = tolower(currentWord)
  endif
  if (index(InterestingWords, currentWord) == -1)
    ColorWord(currentWord, mode)
  else
    UncolorWord(currentWord)
  endif
enddef

def Get_visual_selection(): string
  # Why is this not a built-in Vim script function?!
  [lnum1, col1] = getpos("'<")[1:2]
  [lnum2, col2] = getpos("'>")[1:2]
  lines = getline(lnum1, lnum2)
  lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
  lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
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
  for word in InterestingWords
    if (type(word) == 1)
      mode = InterestingModes[i]
      mid = Mids[word]
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
  index = index(s:recentlyUsed, n)
  remove(s:recentlyUsed, index)
  add(s:recentlyUsed, n)
enddef

def UiMode(): string
  # Stolen from airline's airline#init#gui_mode()
  return ((has('nvim') && exists('$NVIM_TUI_ENABLE_TRUE_COLOR') && !exists("+termguicolors"))
        \ || has('gui_running') || (has("termtruecolor") && &guicolors == 1) || (has("termguicolors") && &termguicolors == 1)) ?
        \ 'gui' : 'cterm'
enddef

# initialise highlight colors from list of GUIColors
# initialise length of InterestingWord list
# initialise s:recentlyUsed list
def BuildColors(): void 
  if (HasBuiltColors)
    return
  endif
  ui = UiMode()
  wordColors = (ui == 'gui') ? g:interestingWordsGUIColors : g:interestingWordsTermColors
  if (exists('g:interestingWordsRandomiseColors') && g:interestingWordsRandomiseColors)
    # fisher-yates shuffle
    i = len(wordColors)-1
    while i > 0
      j = s:Random(i)
      temp = wordColors[i]
      wordColors[i] = wordColors[j]
      wordColors[j] = temp
      i -= 1
    endwhile
  endif
  # select ui type
  # highlight group indexed from 1
  currentIndex = 1
  for wordColor in wordColors
    execute 'hi! def InterestingWord' .. currentIndex .. ' ' .. ui .. 'bg=' .. wordColor .. ' ' .. ui .. 'fg=Black'
    add(InterestingWords, 0)
    add(InterestingModes, 'n')
    add(s:recentlyUsed, currentIndex-1)
    currentIndex += 1
  endfor
  HasBuiltColors = 1
enddef

# helper function to get random number between 0 and n-1 inclusive
def s:Random(n: number): number
  timestamp = reltimestr(reltime())[-2:]
  return float2nr(floor(n * timestamp/100))
enddef

if !exists('g:interestingWordsDefaultMappings') || g:interestingWordsDefaultMappings != 0
  g:interestingWordsDefaultMappings = 1
endif

if g:interestingWordsDefaultMappings && !hasmapto('<Plug>InterestingWords')
  nnoremap <silent> <leader>k :InterestingWords('n')<cr>
  vnoremap <silent> <leader>k :InterestingWords('v')<cr>
  nnoremap <silent> <leader>K :UncolorAllWords()<cr>

  nnoremap <silent> n :WordNavigation(1)<cr>
  nnoremap <silent> N :WordNavigation(0)<cr>
endif

if g:interestingWordsDefaultMappings
  try
    nnoremap <silent> <unique> <script> <Plug>InterestingWords
          \ :InterestingWords('n')<cr>
    vnoremap <silent> <unique> <script> <Plug>InterestingWords
          \ :InterestingWords('v')<cr>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsClear
          \ :UncolorAllWords()<cr>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsForeward
          \ :WordNavigation(1)<cr>
    nnoremap <silent> <unique> <script> <Plug>InterestingWordsBackward
          \ :WordNavigation(0)<cr>
  catch /E227/
  endtry
endif
