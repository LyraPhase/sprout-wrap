# sprout-wrap

[![ci](https://github.com/LyraPhase/sprout-wrap/actions/workflows/ci.yml/badge.svg)](https://github.com/LyraPhase/sprout-wrap/actions/workflows/ci.yml)

# NOTE: This is a Fork!

This project uses [soloist](https://github.com/mkocher/soloist) and [librarian-chef](https://github.com/applicationsonline/librarian-chef)
to run a custom set of the recipes in sprout-wrap's cookbooks.

Additionally, it adds the [`lyraphase_workstation`](https://github.com/trinitronx/lyraphase_workstation) cookbook for installing a Digital Audio Workstation (DAW), and miscellaneous audio and development tools.

## Sponsor

Keeping this bootstrap provisioning project working on each macOS update sure is a lot of work!
If you find this project useful and appreciate my work,
would you be willing to click one of the buttons below to Sponsor this project and help me continue?

- <noscript><a href="https://github.com/sponsors/trinitronx">:heart: Sponsor</a></noscript>
- <noscript><a href="https://liberapay.com/trinitronx/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>
- <noscript><a href="https://paypal.me/JamesCuzella"><img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" border="0" alt="Donate with PayPal" /></a></noscript>

Every little bit is appreciated! Thank you! 🙏


## Prerequisites


## Installation under Mavericks (OS X 10.9)

### The Easy Way:

#### 1. Run bootstrap script

Open a terminal and run:

    \curl -Ls https://git.io/viaJe | bash

### The Semi-Manual Way:

### 1. Install Command Line Tools

[Download](https://developer.apple.com/support/xcode/) and install XCode or the XCode command line tools.
  
    xcode-select --install

## Installation

To provision your machine, open up Terminal and enter the following:

```sh
sudo xcodebuild -license
xcode-select --install
git clone https://github.com/pivotal-sprout/sprout-wrap.git
cd sprout-wrap
caffeinate ./sprout
```

The `caffeinate` command will keep your computer awake while installing; depending on your network connection, soloist can take from 10 minutes to 2 hours to complete.

## Problems?

### ObjectiveC Fork Error

As of macOS `10.14`, the [behavior of underlying ObjectiveC macOS Foundation framework changed][objc-fork-mojave]. (Big surprise, Apple changes fundamental development platform dependencies so often it causes many things to break 🍎💩)
This results in the following errors:

    objc[37813]: +[__NSPlaceholderDictionary initialize] may have been in progress in another thread when fork() was called.
    objc[37813]: +[__NSPlaceholderDictionary initialize] may have been in progress in another thread when fork() was called. We cannot safely call it or ignore it in the fork() child process. Crashing instead. Set a breakpoint on objc_initializeAfterForkError to debug.
    [2020-07-20T16:25:31-06:00] FATAL: Chef::Exceptions::ChildConvergeError: Chef run process terminated by signal 6 (IOT)
    [2020-07-20T16:25:31-06:00] FATAL: Chef::Exceptions::ChildConvergeError: Chef run process terminated by signal 6 (IOT)

The workaround is to run `soloist` / `chef-solo` with the following environment variable:

    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    bundle exec soloist run_recipe homebrew::install_casks ## For example

### clang error

If you receive errors like this:

    clang: error: unknown argument: '-multiply_definedsuppress'

then try downgrading those errors like this:

    sudo ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future bundle

### Command Line Tool Update Server

If you receive a message about the update server being unavailable and are on Mavericks, then you already have the command line tools.

## Customization

This project uses [soloist](https://github.com/mkocher/soloist) and [librarian-chef](https://github.com/applicationsonline/librarian-chef)
to run a subset of the recipes in sprout's cookbooks.

[Fork it](https://github.com/pivotal-sprout/sprout-wrap/fork) to 
customize its [attributes](http://docs.chef.io/attributes.html) in [soloistrc](/soloistrc) and the list of recipes 
you'd like to use for your team. You may also want to add other cookbooks to its [Cheffile](/Cheffile), perhaps one 
of the many [community cookbooks](https://supermarket.chef.io/cookbooks). By default it configures an OS X 
Mavericks workstation for Ruby development.

Finally, if you've never used Chef before - we highly recommend you buy &amp; watch [this excellent 17 minute screencast](http://railscasts.com/episodes/339-chef-solo-basics) by Ryan Bates. 

## Caveats

### Homebrew

- Homebrew cask has been [integrated](https://github.com/caskroom/homebrew-cask/pull/15381) with Homebrew proper. If you are experiencing problems installing casks and
  have an older installation of Homebrew, running `brew uninstall --force brew-cask; brew update` should fix things.
- If you are updating from an older version of sprout-wrap, your homebrew configuration in soloistrc might be under `node_attributes.sprout.homebrew.formulae`
  and `node_attributes.sprout.homebrew.casks`. These will need to be updated to `node_attributes.homebrew.formulas` (note the change from formulae to formulas)
  and `node_attributes.homebrew.casks`.

## Roadmap

See Pivotal Tracker: <https://www.pivotaltracker.com/s/projects/884116>

## Discussion List

  Join [sprout-users@googlegroups.com](https://groups.google.com/forum/#!forum/sprout-users) if you use Sprout.

## References

* Slides from @hiremaga's [lightning talk on Sprout](http://sprout-talk.cfapps.io/) at Pivotal Labs in June 2013
* [Railscast on chef-solo](http://railscasts.com/episodes/339-chef-solo-basics) by Ryan Bates (PAID)

[objc-fork-mojave]: https://blog.phusion.nl/2017/10/13/why-ruby-app-servers-break-on-macos-high-sierra-and-what-can-be-done-about-it/
