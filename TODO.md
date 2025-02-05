<!-- markdownlint-configure-file
{
  "required-headings": {
    "headings": [
      "# TODO",
      "*"
    ]
  }
}
-->

TODO
====

Recipes to Merge in
===================

- fisa-vim-config!
- sprout-vim ??
- [DaisyDisk License handling](https://github.com/trinitronx/sprout/blob/develop/sprout-osx-apps/templates/default/License.DaisyDisk.erb)
- [DaisyDisk Recipe](https://github.com/trinitronx/sprout/blob/develop/sprout-osx-apps/recipes/daisydisk.rb)
- Maybe??
  - `sprout-osx-base::apple-gcc42` => sprout-homebrew: formulae: `apple-gcc42`
  - hub config with node-specific encrypted `data_bag` support for tokens
- Create new recipe for [link `gpg` `SSH_AUTH_SOCK` to `gpg-agent`][9] `LaunchAgent`

macOS Deprecated Cookbook Upgrades
==================================

- [pivotal-sprout/osx][1] cookbook needs replacement!
  - Must support some form of `osx_defaults` and `osx_sysctl` LWRPs
    - [pivotal-sprout/sprout-osx-settings][2] cookbook depends on these LWRPs
  - [Sous-Chefs-Boneyard/mac_os_x][3] cookbook deprecated in favor of [microsoft/macos-cookbook][4] (oh the irony!)
- [carsomyr/chef-plist][5] cookbook needs replacement!
  - Must support some form of `plist_file` LWRP
  - [microsoft/macos-cookbook][6] provides this too... :thinking:
- Non-critical: `sprout-osx-apps::iterm2` superceded by `lyraphase_workstation::iterm2`
  - Fix Idempotency issue with config file: `/Users/jcuzella/Library/Preferences/com.googlecode.iterm2.plist`

Deprecation warnings that must be addressed before upgrading to Chef Infra 18:

    The  resource in the homebrew cookbook should declare `unified_mode true` at 1 location:
      - /var/chef/cache/cookbooks/homebrew/resources/tap.rb
     See https://docs.chef.io/deprecations_unified_mode/ for further details.
    The  resource in the sprout-base cookbook should declare `unified_mode true` at 2 locations:
      - /var/chef/cache/cookbooks/sprout-base/resources/bash_it_custom_plugin.rb
      - /var/chef/cache/cookbooks/sprout-base/resources/bash_it_enable_feature.rb
     See https://docs.chef.io/deprecations_unified_mode/ for further details.
    The  resource in the osx cookbook should declare `unified_mode true` at 2 locations:
      - /var/chef/cache/cookbooks/osx/resources/defaults.rb
      - /var/chef/cache/cookbooks/osx/resources/sysctl.rb
     See https://docs.chef.io/deprecations_unified_mode/ for further details.
    The  resource in the plist cookbook should declare `unified_mode true` at 1 location:
      - /var/chef/cache/cookbooks/plist/resources/file.rb
     See https://docs.chef.io/deprecations_unified_mode/ for further details.
    The  resource in the dmg cookbook should declare `unified_mode true` at 1 location:
      - /var/chef/cache/cookbooks/dmg/resources/package.rb
     See https://docs.chef.io/deprecations_unified_mode/ for further details.
    The  resource in the sprout-osx-apps cookbook should declare `unified_mode true` at 1 location:
      - /var/chef/cache/cookbooks/sprout-osx-apps/resources/sublime_package.rb
     See https://docs.chef.io/deprecations_unified_mode/ for further details.

Misc
====

- Should this fork change name & graduate to full-fledged non-fork repo?
  - Pros:
    - No more accidental pull requests to upstream
    - Fully-fledged "greenfield" namespace
    - Freedom to take project in new directions
  - Cons:
    - Not as easy to push changes back upstream (if it becomes active again)
    - Not as much community support (if it becomes active again)
  - Alternative "sprout"-themed name brainstorming:
    - sprig
    - shoot (too generic, has alternate meaning)
    - twig
    - seed
    - seedling
    - sapling
    - plant
    - leaf
    - cotyledon
  - "sprout-wrap" Alternatives:
    - exocarp
    - seed-coat
    - endocarp
- Update GitHub `known_hosts` keys to use [their newer public key algorithms][7]:
- ECDSA:
- Ed25519:

        ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
- Add recipe for [installing Rosetta][8] on M1 Macs / Apple Silicon:

        softwareupdate --install-rosetta

- Idea: Switch to installing Xcode via [xcodes][10] and [Homebrew formula][11] to avoid the automation headaches
- Idea: Cookbook / recipe to install `go` tools:

        go install -v github.com/ramya-rao-a/go-outline@latest
        go install -v github.com/josharian/impl@latest
        go install -v github.com/uudashr/gopkgs/v2/cmd/gopkgs@latest
        go install -v github.com/haya14busa/goplay/cmd/goplay@latest

  - Manually Installed Tools List:
    - [go-outline][12]: Extracts JSON representations for declarations in Go source files.
    - [impl][13]: Go [Interface Code Snippet Generator][14]
    - [gopkgs][15]: Tool to list all available Go packages
    - [goplay][16]: The [Go Playground][17] client

  - Homebrew Installed Tools List:
    - [gomodifytags][18]: Go tool to modify/update field tags in structs.
    - [go][19]: Go Language (a.k.a. GoLang)
    - [delve][20]: Go Debugger
    - [gopls][21]: Go Language Server providing IDE features via LSP / Language Server Protocol
    - [gomplate][22]: Go Template renderer
    - [gotests][23]: Generate tests based `.go` source files' function signatures
    - [staticcheck][24]: Static analysis Linter for Go
    - [mockery][25]: Mock code autogenerator for Golang

[1]: https://github.com/pivotal-sprout/osx
[2]: https://github.com/pivotal-sprout/sprout-osx-settings
[3]: https://github.com/Sous-Chefs-Boneyard/mac_os_x/issues/20
[4]: https://github.com/Microsoft/macos-cookbook
[5]: https://github.com/carsomyr/chef-plist/tree/master/vendor/cookbooks/plist
[6]: https://github.com/microsoft/macos-cookbook/blob/master/resources/plist.rb
[7]: https://github.blog/2021-09-01-improving-git-protocol-security-github/
[8]: https://docs.docker.com/desktop/mac/apple-silicon/
[9]: https://evilmartians.com/chronicles/stick-with-security-yubikey-ssh-gnupg-macos
[10]: https://github.com/RobotsAndPencils/xcodes
[11]: https://github.com/RobotsAndPencils/homebrew-made/blob/master/Formula/xcodes.rb
[12]: https://github.com/ramya-rao-a/go-outline
[13]: https://github.com/josharian/impl
[14]: https://levelup.gitconnected.com/implementing-golang-interfaces-like-a-boss-73a0f7757597
[15]: https://github.com/uudashr/gopkgs
[16]: https://github.com/haya14busa/goplay
[17]: https://play.golang.org
[18]: https://github.com/fatih/gomodifytags
[19]: https://go.dev/
[20]: https://github.com/go-delve/delve
[21]: https://github.com/golang/tools/tree/master/gopls
[22]: https://docs.gomplate.ca/
[23]: https://github.com/cweill/gotests
[24]: https://staticcheck.io/
[25]: https://github.com/vektra/mockery
