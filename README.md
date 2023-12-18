# lnkr [lˈɪŋkə]

[![GitHub version](https://img.shields.io/github/release/usommerl/lnkr.svg?style=for-the-badge)](https://github.com/usommerl/lnkr/releases)
[![build](https://img.shields.io/github/workflow/status/usommerl/lnkr/ci?style=for-the-badge)](https://github.com/usommerl/lnkr/actions?query=workflow%3Aci)
[![build](https://img.shields.io/github/actions/workflow/status/usommerl/lnkr/ci.yml?branch=develop&style=for-the-badge)](https://github.com/usommerl/lnkr/actions?query=workflow%3Aci)
[![codecov](https://img.shields.io/codecov/c/github/usommerl/lnkr?style=for-the-badge)](https://codecov.io/gh/usommerl/lnkr)

*lnkr* is a set of shell functions that help with installation and removal of configuration files. A widespread pattern for managing such files is to keep them in a *git* repository and create a symlink for each file at the correct filesystem location. *lnkr* is intended for this scenario and takes care of the symlinks.

<!--**Wait, I can write my own shell script that uses *ln*. Why should I care?**-->

### Dependencies
The following tools are required in order to use *lnkr*:

 - [GNU bash][6]
 - [GNU coreutils][2]
 - [GNU sed][5]
 - [curl][7]
 - [git][3]
 - [sudo][4] (*optional*)

### Caveat emptor

I've started to build _lnkr_ a couple of years ago because I couldn't find any other tool that suits my needs. Now there are a plethora of configuration management solutions. You most probably should look into them first! Here is a [comprehensive list][1].

<!--### Design considerations-->

<!--### Usage-->

<!--### Contributing-->

[1]: https://dotfiles.github.io/utilities/
[2]: https://www.gnu.org/software/coreutils/
[3]: https://git-scm.com/
[4]: https://github.com/sudo-project/sudo
[5]: https://www.gnu.org/software/sed/
[6]: https://www.gnu.org/software/bash/
[7]: https://github.com/curl/curl
