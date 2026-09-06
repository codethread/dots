export const keybindings = [
    {
        name: open_help_menu
        modifier: alt
        keycode: char_/
        mode: [emacs, vi_insert, vi_normal]
        event: {send: menu, name: help_menu}
    }
    {
        name: reload_config
        modifier: alt
        keycode: char_x
        mode: emacs
        event: [
            {edit: clear}
            {
                send: executehostcommand
                cmd: $"source '($nu.env-path)'; source '($nu.config-path)'; source '($nu.loginshell-path)'"
            }
        ]
    }
    {
        name: fuzzy_dir
        modifier: alt
        keycode: char_c
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: "cd (fd --hidden --type d --exclude '{Library,Music,Applications,Pictures,Unity,VirtualBox VMs,WebstormProjects,Tools,node_modules,.git,.cargo,go}' . $env.HOME | fzf)"}
    }
    # TODO: need to fix these:
    {
        name: fuzzy_module
        modifier: control
        keycode: char_y
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: '
			commandline --replace "use "
			commandline --insert (
			$NU_LIB_DIRS
			| each {|dir|
			ls ($dir | path join "**" "*.nu")
			| get name
			| str replace $dir ""
			| str trim -c "/"
			}
			| flatten
			| input list --fuzzy
			$"Please choose a (ansi magenta)module(ansi reset) to (ansi cyan_underline)load(ansi reset):"
			)
			'}
    }
    {
        name: fuzzy_insert_dir
        modifier: control
        keycode: char_t
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: "
			commandline -a (
			fd --type=directory
			| lines
			| input list --fuzzy
			$'Please choose a (ansi magenta)directory(ansi reset) to (ansi cyan_underline)insert(ansi reset):'
			)"}
    }
    {
        name: fuzzy_file
        modifier: control
        keycode: char_v
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: "
			commandline -a (
			rg --files-with-matches --hidden .
			| lines
			| input list --fuzzy
			$'Please choose a (ansi magenta)file(ansi reset) to (ansi cyan_underline)insert(ansi reset):'
			)"}
    }
]
