vim9script
scriptencoding utf-8

if get(g:, 'loaded_autoload_asyncomplete_sources_html_id')
	finish
endif
g:loaded_autoload_asyncomplete_sources_html_id = 1

export def GetSourceOptions(opts: dict<any>): dict<any>
	return extend(extend({}, opts), {
				name: 'html-id',
				completor: function('asyncomplete#sources#html_id#Completor'),
				refresh_pattern: '[0-9a-z./_#-]',
				allowlist: ['html', 'xhtml'],
				triggers: {'*': [' ', "\t", '/', '#', '=', "'", '"']},
				# * スペースは複数クラスの区切り
				# * / はパス区切り
				# * # は ID の書き始め
				# * =,",' は属性値の書き始め
			})
enddef

def ReadFile(f: string): list<string>
	var file: string = resolve(expand(f))
	var buf: list<dict<any>> = filter(getbufinfo(), (_, v) => v.name ==# file)

	if !!len(buf)
		return getbufline(buf[0].bufnr, 1, '$')
	elseif filereadable(file)
		return readfile(file)
	endif
	return []
enddef

def GetIdCore(lines_org: list<string>, p: list<string>, cls_ids: dict<dict<list<string>>>, path: string, pat: string): void
	var lines: list<string> = mapnew(lines_org, (_, v) => v->substitute('/\*\([^/]\|[^*]/\)*\*/', '', 'g'))
	var tag: string
	var kind: string
	var arg: string
	var paths: list<string> = p
	var class_ids: dict<dict<list<string>>> = cls_ids
	var search_s: string = '\c\([a-z]*\)\([.#]\)\(' .. pat .. '*\)'
	var comment_f: number # 0x1: コメント内、0x2: コメント開始終了が書かれた行
	var line: string

	for l in lines
		line = l
		if line =~# '\*/'
			line = substitute(line, '\([^/]\|[^*]/\)*\*/', '', '')
			comment_f = xor(or(comment_f, 0x3), 0x1)
		endif
		if line =~# '/\*'
			line = substitute(line, '/\*\([^/]\|[^*]/\)*', '', '')
			comment_f = or(comment_f, 0x3)
		endif
		if !!and(comment_f, 0x1)
			if !!and(comment_f, 0x2)
				comment_f = xor(comment_f, 0x2)
			else
				continue
			endif
		endif
		for m in matchstrlist([line], search_s .. "[ \t,{*>+~]", {submatches: true})
					->map((_, v) => v.submatches)
			[tag, kind, arg] = m[0 : 2]
			kind = kind ==# '.' ? 'class' : 'id'
			if !tag
				add(class_ids['*'][kind], arg)
			else
				if !has_key(class_ids, tag)
					class_ids[tag] = {class: [], id: []}
				endif
				add(class_ids[tag][kind], arg)
			endif
		endfor
		for s in matchstrlist([line], '^\s*@import\s\+url(\zs\([^)]\+\|"[^"]\+"\|''[^'']\+''\)\ze);')
					->map((_, v) => v.text->substitute('\("\([^"]\)\+"\|''\([^'']\+\)''\)', '\2\3', ''))
			GetIdFile(paths, class_ids, path, s, pat)
		endfor
	endfor
	return
enddef

def GetIdFile(p: list<string>, cls_ids: dict<dict<list<string>>>, d: string, f: string, pat: string): void
	var paths: list<string> = p
	var class_ids: dict<dict<list<string>>> = cls_ids
	var path: list<string> = p
	var file: string
	if f =~# '^\~/' || f =~# '^/'
		file = resolve(expand(f))
	elseif f =~# '^https\?://'
		return
	else
		file = resolve(fnamemodify(d, ':h') .. '/' .. f)
	endif
	if index(paths, file) == -1
		GetIdCore(ReadFile(file), paths, class_ids, file, pat)
		add(paths, file)
	endif
	return
enddef

export def Completor(opt: dict<any>, ctx: dict<any>): void
	var tag: string
	var kind: string = synIDattr(synID(line('.'), col('.'), 1), 'name')
	var pat: string = asyncomplete#sources#html_id#GetSourceOptions({}).refresh_pattern
	var f_pat: string = substitute(pat, '#', '', 'g')
	var id_pat: string = '\c[a-z]' .. substitute(f_pat, '[/.]', '', 'g')
	var class_ids: dict<dict<list<string>>> = {'*': {class: [], id: []}}
	f_pat = '\c' .. f_pat

	def CSSClassIDs(cls_ids: string): list<dict<any>>
		def GetId(): dict<dict<list<string>>>
			var paths: list<string>
			var head: number
			var s: string
			var css_lines: list<string>

			for l in getline(1, '$')
				s = substitute(l, '<!--\([^>]\|[^-]>\|[^-]->\)*-->', '', 'g')
				if s =~? '^\c\s*<head>'
					head = 1
				elseif s =~? '^\c\s*</head>'
					break
				elseif !!and(head, 0x1)
					if s =~? '^\c\s*<style\>'
						head = or(head, 0x2)
					elseif s =~? '^\c\s*</style>'
						GetIdCore(css_lines, paths, class_ids, resolve(expand('%:p')), id_pat)
						head = xor(head, 0x2)
					elseif s =~? '\c<link\(\s\+\(rel="stylesheet"\|rel=''stylesheet''\|rel=stylesheet\|type="text/css"\|type=''text/css''\|href=\("[^"]\+"\|''[^'']\+''\)\)\)\+\(\s*/\)\?>'
						GetIdFile(paths, class_ids, expand('%:p'), matchstr(s, '\c\<href=\("\zs[^"]\+\ze"\|''\zs[^'']\+\ze''\)'), id_pat)
					elseif !!and(head, 0x2)
						add(css_lines, l)
					endif
				endif
			endfor
			return class_ids
		enddef

		var snip: list<string>
		class_ids = GetId()
		snip = class_ids['*'][kind]
		if has_key(class_ids, tag)
			extend(snip, class_ids[tag][kind])
		endif
		if !snip
			return []
		endif
		sort(snip)->uniq()
		for c in split(cls_ids, ' ')[0 : -2] # 設定済み class/id の確認のためカーソル位置の指定は敢えて候補に残しておく
			filter(snip, (_, v) => v !=# c )
		endfor
		return mapnew(snip, (_, v) => ({
			word: v,
			kind: 'html-id',
			menu: '[class/id: ' .. kind .. ']'
		}))
	enddef

	def Files(s: string): list<dict<any>>
		var pre: string
		var base: string
		var f_pre: string
		var snip: list<string>
		var url_kind: string

		def Sort(item1: dict<any>, item2: dict<any>): number
			if item1.menu ==# '[path/id: dir]'
					&& item2.menu !=# '[path/id: dir]'
				return -1
			endif
			if item1.menu !=# '[path/id: dir]'
					&& item2.menu ==# '[path/id: dir]'
				return 1
			endif
			return 0
		enddef

		def Title(f: string): string
			var ext: string = fnamemodify(f, ':e')
			var head: number
			var title: list<string>

			if ( ext !=? 'html' && ext !=? 'xhtml' && ext !=? 'htm'  ) || !filereadable(f)
				return ''
			endif
			for l in ReadFile(expand('%:p:h') .. '/' .. f)
				if l =~? '\c<head>'
					head = 0x1
				endif
				if l =~? '\c<title>'
					head->and(0x2)
					if l !~? '\c<title>$'
						add(title, l)
					endif
				endif
				if l =~? '\c</title>' && !!xor(head, 0x03)
					if l !~? '^\c\s*</title>' && index(title, l) == -1
						add(title, l)
					endif
					break
				elseif l =~? '\c</head>' || l =~? '\c<body'
					break
				endif
			endfor
			return map(title, (_, v) => substitute(v, '<[^>]\+>', '', 'g')
				->substitute('^\s\+', '', '')
				->substitute('\s\+$', '', '')
				->substitute('&lt;', '<', 'g')
				->substitute('&gt;', '>', 'g')
				->substitute('&amp;', '\&', 'g'))
				->join('')
		enddef

		base = fnamemodify(s, ':t')
		if !s
			pre = './'
		elseif isdirectory(s)
			if s[-1] ==# '/'
				pre = s
			else
				pre = fnamemodify(s, ':h')
				f_pre = base
			endif
		else
			pre = fnamemodify(s, ':h')
			f_pre = base
		endif
		if s =~# '^\./'
			snip = globpath(pre, '*', true, true)
		else
			snip = globpath(pre, '*', true, true)->map((_, v) => substitute(v, '^\./', '', ''))
		endif
		if !!snip
			return mapnew(snip, (_, v) => ( {
					word: v,
					kind: 'html-id',
					menu: isdirectory(v) ? '[path/id: dir]' : '[path/id: file]',
					abbr: fnamemodify(v, ':t') .. ( isdirectory(v) ? '/' : '' ),
					info: Title(v),
					icase: 0,
					dup: 0
				})
			)->sort(Sort)
		endif
		return []
	enddef

	def IDs(f: string, typed_s: string): list<any>
		def IdCore(lines_org: list<string>): list<dict<string>>
			def Around(lines: list<string>, s: string, m: string): string
				var around: list<string> = [s[matchstrpos(s, m)[1] : ]]
				var tags: list<string> = matchstrlist([s[matchstrpos(s, m)[1] : ]], '<\zs/\?[a-z]\+\>')->map((_, v) => v.text)
				var c_tags: list<string>
				var tag1st = tags[0]
				var num: number = 0
				var tags_n: number
				var i: number
				var m_linenum: number = index(mapnew(lines, (_, v) => v->substitute('<!--\([^>]\|[^-]>\|[^-]->\)*-->', '', 'g')), s)
				var not_close_tag: string = '\c\(br\|hr\|img\|col\|base\|link\|meta\|input\|keygen\|area\|param\|embed\|source\|track\)'

				if tag1st =~? '\<' .. not_close_tag .. '\>'
					return lines[m_linenum : min([m_linenum + 40, len(lines) - 1])]->join("\n")
				endif
				tag1st = '/' .. tag1st
				filter(tags, (_, v) => v !~? not_close_tag)
				tags = tags[1 : ]
				for l in lines[m_linenum + 1 : ]
					if num >= 40
						break
					endif
					while true # 対応するタグが連続していれば削除
						tags_n = len(tags) - 1
						if tags_n <= 0 # タグがない、一つの場合は対応するタグはない
							break
						endif
						i = 0
						c_tags = []
						while i < tags_n
							if '/' .. tags[i] !=? tags[i + 1]
								add(c_tags, tags[i])
								i += 1
							else
								i += 2
							else
							endif
						endwhile
						if i == tags_n
							add(c_tags, tags[-1])
						endif
						if tags_n == len(c_tags) - 1
							break
						endif
						tags = deepcopy(c_tags)
					endwhile
					if !!len(tags)
							&& (
							tags[0] =~? tag1st
							|| filter(deepcopy(tags),
									(_, v) => v != '\<\(colgroup\|dd\|dt\|li\|optgroup\|option\|p\|rp\|rt\|tbody\|td\|tfoot\|th\|thead\|tr\)\>')[0] =~? tag1st
							)
						break
					endif
					tags += matchstrlist([substitute(l, '<!--\([^>]\|[^-]>\|[^-]->\)*-->', '', 'g')], '<\zs/\?[a-z]\+\>')->map((_, v) => v.text)
					add(around, l)
					num += 1
				endfor
				return join(around, "\n")
			enddef

			var lines: list<string> = mapnew(lines_org, (_, v) => v->substitute('/\*\([^/]\|[^*]/\)*\*/', '', 'g'))
			var search_s: string = '\c\(<[a-z]\+\>[^>]*\)\?\<id=\("\(' .. id_pat .. '*\)"\|''\(' .. id_pat .. '*\)''\|\(' .. id_pat .. '*\)\)'
			var match_l: number
			var all: string
			var s: string
			var comment_f: number
			var id0: string
			var id1: string
			var id2: string
			var tmp: string
			var ids: list<dict<string>>

			for l in lines
				s = l
				if s =~# '-->'
					s = substitute(s, '\([^>]\|[^-]>\|[^-]->\)*-->', '', '')
					comment_f = xor(or(comment_f, 0x3), 0x1)
				endif
				if s =~# '<!--'
					s = substitute(s, '<!--\([^>]\|[^-]>\|[^-]->\)*', '', '')
					comment_f = or(comment_f, 0x3)
				endif
				if !!and(comment_f, 0x1)
					if !!and(comment_f, 0x2)
						comment_f = xor(comment_f, 0x2)
					else
						continue
					endif
				endif
				while true
					match_l = match(s, search_s)
					if match_l < 0
						break
					endif
					[all, tmp, tmp, id0, id1, id2] = matchlist(s, search_s)[0 : 5]
					s = s[match_l + len(all) : ]
					add(ids, ({
						id: id0 ?? (id1 ?? id2),
						info: Around(lines_org, l, all)
					}))
				endwhile
			endfor
			return ids
		enddef

		var snip: list<dict<string>>

		if !f
			snip = IdCore(getline(1, '$'))
		else
			snip = IdCore(ReadFile(expand('%:p:h') .. '/' .. f))
		endif
		if !!typed_s
			snip = matchfuzzy(snip, typed_s, {key: 'id'})
		endif
		if !snip
			return []
		endif
		return mapnew(snip, (_, v) => ({
			word: v.id,
			kind: 'html-id',
			menu:  '[path/id: id]',
			info: v.info,
			icase: 0,
			dup: 0
		}))->sort('i')
	enddef

	var typed: string = ctx['typed']
	var col: number = ctx['col']
	var matches: list<dict<any>>
	var arg: string
	var url: string
	var path: string
	var hash: string
	var id: string
	var match_s: list<string>

	if kind !=# 'htmlString' && kind !=# 'htmlValue' && kind !=# 'htmlTag'
		return
	endif
	match_s = matchlist(typed,
		'\c\%(<\([a-z]\+\)\>[^>]*\)\?\<\%(\(class\|id\)=["'']\?\(\%(' .. id_pat .. '*\|[ \t]\)*\)\|\(src\|href\)=["'']\(\~\?' .. f_pat ..  '*\)\(#\(' .. id_pat .. '*\)\?\)\?\)$')
	if !match_s
		return
	endif
	[tag, kind, arg, url, path, hash, id] = match_s[1 : 7]
	if kind ==? 'class' || kind ==? 'id'
		col = col - len(matchstr(typed, '\%(' .. id_pat .. '*\)\?$'))
		matches = CSSClassIDs(id)
	elseif tag ==? 'a' && url ==? 'href' && hash !=? ''
		col = col - len(matchstr(typed, '#\zs\%(' .. id_pat .. '*\)\?$'))
		matches = IDs(path, id)
	else # match_s, kind 両方が空では無いので、src/href のどちらかがヒットしているはずなので、追加条件は必要ないはず
		col = col - len(matchstr(typed, '\~\?' .. f_pat ..  '*$')) # simplify() を使って単純化できるように、ファイル名だけでなくパス全体を補完対象とする
		# ただし他のファイル名補完と相性が悪くなるので、g:asyncomplete_preprocessor の関数で対処する必要が出てくる
		matches = Files(path)
	endif
	asyncomplete#complete(opt['name'], ctx, col, matches, 1)
	return
enddef
defcompile
