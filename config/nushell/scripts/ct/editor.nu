# Editor and development environment utilities

# see https://github.com/wbthomason/packer.nvim/issues/180 for MACOSX_DEPLOYMENT_TARGET=10.15
export alias nvim-boot = MACOSX_DEPLOYMENT_TARGET=10.15 nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

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
