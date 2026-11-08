# Editor and development environment utilities

export def nvim-md []: string -> nothing {
    $in | nvim - "+set ft=markdown"
}

export def nvim-profile [] {
    nvim -c "lua require('lazy').profile()"
}

export def lv [...arg: string] {
    with-env {NVIM_APPNAME: Lazyvim} {
		nvim ...$arg
	}
}

export def nvim-sync [] {
    nvim --headless "+Lazy! clean" +qa
    nvim --headless "+Lazy! install" +qa
}

export alias nn = nvim '+Telescope find_files'
