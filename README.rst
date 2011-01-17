.. contents:: :backlinks: none

Usage
~~~~~
Exactly as you would pacman_. *auryea* can be configured to wrap pacman or
behave as a standalone package manager of sorts entirely for AUR_.

Configuration
~~~~~~~~~~~~~
*auryea* is configured entirely through environment variables. To make settings
persist, simply ``export`` the variables in your ``~/.bash_profile``,
``~/.zshrc``, ``~/.profile``, or ``/etc/profile``.

======================= ======================= =================================
        Variable             Default value                  Purpose
======================= ======================= =================================
AURYEA_WRAP_PACMAN      1                       If true, *auryea* will call pass
                                                pacman all arguments before doing
                                                any operation.
AURYEA_PACMAN_SEARCH    0                       If true, *auryea* will call
                                                ``pacman -Ss {terms}`` *after*
                                                searching AUR_.
AURYEA_USE_SHELL        1                       If true, *auryea* will prompt to
                                                execute your default shell from
                                                the directory of the extracted
                                                package, allowing you to edit the
                                                ``PKGBUILD``, debug errors, or
                                                anything else you'd like to do.
AURYEA_SHELL_NOPROFILE  1                       If true, *auryea* runs your
                                                default shell without a profile
                                                or rc file (currently only works 
                                                with **bash** or **zsh**).
AURYEA_TMP_DIRECTORY    ``/tmp/auryea-${USER}`` The directory where packages
                                                should be downloaded to.
AURYEA_PARSE_DEPENDS    1                       If true, *auryea* parses the
                                                ``PKGBUILD``'s ``depends`` and
                                                ``makedepends`` and syncs any
                                                uninstalled dependencies.
AURYEA_NO_REINSTALL     0                       If true, *auryea* will not 
                                                attempt to reinstall a package
                                                if already synced and 
                                                up-to-date.
AURYEA_VERBOSE_INSTALL  1                       If true, *auryea* prints the
                                                package category, name, version,
                                                and (optionally) description 
                                                before syncing.
AURYEA_COMPACT_SEARCH   0                       If true, *auryea* omits the
                                                package description when printing
                                                package metadata before syncing.
PACMAN_OPTS             ``""``                  Additional arguments that are
                                                passed to pacman.
MAKEPKG_OPTS            ``""``                  Additional arguments that are
                                                passed to makepkg.
======================= ======================= =================================

Tips & Tricks
~~~~~~~~~~~~~

    - **Searching with wilcdards:**

      .. sourcecode:: bash

            ~> auryea -Ss "xfce4-*-git"
            searching AUR...
            1. xfce/xfce4-taskmanager-git 20091125-1
            2. xfce/xfce4-dev-tools-git 20090925-1 [installed:20100728-1]
            3. none/xfce4-power-manager-git 20101112-2
            4. xfce/xfce4-notifyd-git 20101211-1
            5. xfce/xfce4-vala-git 20100303-1
            6. xfce/xfce4-generic-slider-git 20100826-1
            7. xfce/xfce4-volumed-git 20101214-2 [installed:20100728-1]
            8. xfce/xfce4-sensors-plugin-git 20101121-1
            9. devel/xfce4-perl-git 20091101-1
            10. xfce/xfce4-mixer-git 20100128-1
            11. none/xfce4-settings-git 20100408-2 [installed:20100906-1]
            12. none/xfce4-panel-git 20101030-2 [installed:20100729-1]
            13. none/xfce4-session-git 20100408-2
            14. none/xfce4-appfinder-git 20100408-2
            15. none/xfce4-weather-plugin-git 20100415-1
            16. none/xfce4-systemload-plugin-git 20100810-1
            17. xfce/xfce4-datetime-plugin-git 20110103-1

    - **Sync packages, no questions asked:**

      .. sourcecode:: bash
      
            ~> cat << EOF >> .zshrc
            ...> export AURYEA_WRAP_PACMAN=0
            ...> export AURYEA_USE_SHELL=0
            ...> export AURYEA_COMPACT_SEARCH=1
            ...> EOF


.. _AUR: http://aur.archlinux.org
.. _pacman: https://wiki.archlinux.org/index.php/Pacman