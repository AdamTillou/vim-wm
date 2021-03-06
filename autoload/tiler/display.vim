" ==============================================================================
" Rendering functions
" ==============================================================================
" FUNCTION: tiler#display#Render() {{{1
function! tiler#display#Render()
	" Remove all non blank buffers from the list
	" Prepare for rendering
	call tiler#autocommands#Disable()
	let layout = tiler#api#GetLayout()
	let layout.size = 1

	" Close all windows except for the current one
	noa call win_gotoid(tiler#api#GetCurrent().window)
	noa wincmd o
	let windows_window = win_getid()

	" Load the sidebar
	let g:tiler#sidebar.windows[tabpagenr()] = []
	if g:tiler#sidebar.open
		call tiler#display#RenderSidebar()
	endif

	" Form the split layout
	noa call win_gotoid(windows_window)
	call tiler#display#LoadSplits(tiler#api#GetLayout(), 1)

	" Set the sizes of all of the windows in the window list
	call tiler#display#LoadLayout(1)

	" Redisable the autocommands
	call tiler#autocommands#Disable()

	" Return to the origional window
	if g:tiler#sidebar.focused
		noa call win_gotoid(g:tiler#sidebar.windows[tabpagenr()][0])
	else
		noa call win_gotoid(tiler#api#GetCurrent().window)

		" Set the color of the current window if a special color is specified
		call tiler#colors#HighlightCurrent()
	endif

	call tiler#autocommands#Enable()
endfunction
" }}}
" FUNCTION: tiler#display#RenderSidebar() {{{1
function! tiler#display#RenderSidebar()
	" Save the current winid for later
	let nonsidebar_window = win_getid()

	" Run the command to open the sidebar
	silent! execute g:tiler#sidebar.command

	" Get a list of window ids after opening the sidebar
	let g:tmp = g:tiler#sidebar.current
	let g:tiler#sidebar.current.buffers = []
	for i in range(1, winnr("$"))
		let window_id = win_getid(i)

		if window_id != nonsidebar_window
			call add(g:tiler#sidebar.windows[tabpagenr()], window_id)
			call add(g:tiler#sidebar.current.buffers, bufnr(win_id2win(window_id)))
		endif
	endfor

	" Create a blank window if a window wasn't created
	if !exists("g:tiler#sidebar.windows[tabpagenr()]") || len(g:tiler#sidebar.windows[tabpagenr()]) < 1
		new
		let g:tiler#sidebar.windows[tabpagenr()] = [win_getid()]
	endif

	" Move the sidebar windows into a column and set settings
	for i in range(len(g:tiler#sidebar.windows[tabpagenr()]))
		noa call win_gotoid(g:tiler#sidebar.windows[tabpagenr()][i])
		noa wincmd J

		setlocal nobuflisted
		setlocal nonumber
		setlocal winfixwidth
		setlocal statusline=\ 

		if g:tiler#colors#enabled
			setlocal fillchars=vert:\ 
		endif

		call tiler#colors#HighlightSidebar()
	endfor

	" Move the origional window to the right
	noa call win_gotoid(nonsidebar_window)
	if g:tiler#sidebar.side == 'right'
		noa wincmd H
	else
		noa wincmd L
	endif

	" Figure out the size and resize the sidebar
	noa call win_gotoid(g:tiler#sidebar.windows[tabpagenr()][0])
	if g:tiler#sidebar.size > 1
		let sidebar_size = g:tiler#sidebar.size
	else
		let sidebar_size = &columns * g:tiler#sidebar.size
	endif
	execute "vertical resize " . string(sidebar_size)
endfunction
" }}}

" FUNCTION: tiler#display#LoadSplits(pane, first) {{{1
function! tiler#display#LoadSplits(pane, first)
	if a:first
		call tiler#autocommands#Disable()
	endif

	" Open a window
	if a:pane["layout"] == "w"
		" Open the correct buffer in the window if the buffer exists
		if exists("a:pane.buffer") && index(range(1, bufnr("$")), a:pane.buffer) != -1
			execute "buffer " . a:pane.buffer
		endif

		" Give the pane a window number if it doesn't have one already
		let a:pane.window = win_getid()

	else
		" Set up the splits
		let split_cmd = (a:pane.layout == "h") ? "vsplit" : "split"
		let a:pane.children[0].window = win_getid()
		for i in range(1, len(a:pane.children) - 1)
			noa execute split_cmd
			let a:pane.children[i].window = win_getid()
		endfor

		" Return to each split and set it up
		for i in range(len(a:pane.children))
			noa call win_gotoid(a:pane.children[i].window)

			if tiler#display#LoadSplits(a:pane.children[i], 0) == 1
				return 1
			endif
		endfor

		if has_key(a:pane, "window")
			call remove(a:pane, "window")
		endif
	endif

	if a:first
		call tiler#autocommands#Enable()
	endif
	return 0
endfunction
" }}}
" FUNCTION: tiler#display#LoadPanes(pane, id, size, first) {{{1
function! tiler#display#LoadPanes(pane, id, size, first)
	let a:pane.id = a:id

	" Disable the autocommands so that they aren't triggered everytime a new
	" split is created
	if a:first
		call tiler#autocommands#Disable()
	endif

	" Open a window
	if a:pane["layout"] != "w"
		" Set up the children
		for i in range(len(a:pane.children))
			" Figure out the new size
			if a:size == []
				let new_size = []
			else
				let size_index = a:pane.layout == "h" ? 0 : 1
				let new_size = a:size[0:1]
				let new_size[size_index] = 1.0 * a:size[size_index] * a:pane.children[i].size
			endif

			let new_id = a:id[0:-1]
			call add(new_id, i)

			" Go to the window and load it
			call tiler#display#LoadPanes(a:pane.children[i], new_id, new_size, 0)
		endfor

	else
		noa call win_gotoid(a:pane.window)

		" Set it to the default window color
		call tiler#colors#HighlightWindow()

		if a:size != []
			if g:tiler#sidebar.open
				execute "vertical resize " . string((&columns - tiler#sidebar#GetWidth()) * a:size[0])
			else
				execute "vertical resize " . string(&columns * a:size[0])
			endif

			" Subtract 1 because of statusline of each window
			execute "resize " . string(&lines * a:size[1] - 1)
		endif
	endif


	if a:first
		if a:size != [] && g:tiler#sidebar.open
			noa call win_gotoid(g:tiler#sidebar.windows[tabpagenr()][0])
			execute "vertical resize " . string(tiler#sidebar#GetWidth())
		endif

		if a:size != []
			if g:tiler#sidebar.focused
				" Go to the current nonsidebar window first, so that it will be stored
				" as the alternate window
				noa call win_gotoid(tiler#api#GetCurrent().window)
				" Return to the sidebar
				noa call win_gotoid(g:tiler#sidebar.windows[tabpagenr()][0])
			else
				" Return to the origional sidebar and set the window color
				noa call win_gotoid(tiler#api#GetCurrent().window)
				call tiler#colors#HighlightCurrent()
			endif
		endif

		" Reenable the autocommands
		call tiler#autocommands#Enable()
	endif
endfunction
" }}}
" FUNCTION: tiler#display#LoadLayout(resize) {{{1
function! tiler#display#LoadLayout(resize)
	if a:resize == 1
		let size_arg = [1, 1]
	elseif a:resize == 0
		let size_arg = []
	elseif g:tiler#always_resize
		let size_arg = [1, 1]
	else
		let size_arg = []
	endif

	let current_layout = tiler#api#GetLayout()

	call tiler#display#LoadPanes(current_layout, [0], size_arg, 1)
endfunction
" }}}
