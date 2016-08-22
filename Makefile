#---------------------------------------------------------------------
# CentOS_InitialSetting
#---------------------------------------------------------------------
# make 実行ホスト情報
#　　ホスト名、OSバージョンによって動作を変える為
#
D=$(shell date +%Y%m%d-%H%M%S)
HOSTNAME=$(shell hostname)
OS=$(shell /bin/sed -e 's/^.*release \([0-9]\).*/CentOS\1/g' /etc/redhat-release)
#
#---------------------------------------------------------------------
#
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
.PHONY: printpath
printpath:
	@echo ${PATH}
#
#---------------------------------------------------------------------
# オプション無しで make 実行時の動作
#---------------------------------------------------------------------
#
.PHONY: all
all:
	@echo "Usage: make target."
	@echo "  for example, make init"
#
#---------------------------------------------------------------------
# copy
#---------------------------------------------------------------------
#
.PHONY: copy
copy:
	rsync -azv --delete /home/maru/emacs 10.0.2.141:/home/maru/
#
#---------------------------------------------------------------------
# init
#---------------------------------------------------------------------
#
.PHONY: init
init: emacs
### init: update git yum_priorities epel rpmforge emacs initial_pkg_install \	###
### 	useradd home-backup su postfix aliases grub firewalld timezone \	###
### 	selinux bashrc ntp snmpd sudoers #td-agent	###
	@echo ""
	@echo "make init is completed."
#
#---------------------------------------------------------------------
# rsync
#---------------------------------------------------------------------
#
.PHONY: rsync
rsync:	~/.ssh/id_rsa.pub
	ssh-copy-id $(EMACS_SRC_HOST)
	$(MAKE) rsync_emacs_src #init
#
#---------------------------------------------------------------------
# ~/.ssh/id_rsa.pub
#---------------------------------------------------------------------
#
~/.ssh/id_rsa.pub:
	ssh-keygen
#
#---------------------------------------------------------------------
# CentOS バージョン表示
#---------------------------------------------------------------------
#
.PHONY: os
os:
	@echo $(OS)
#
#---------------------------------------------------------------------
# XenTools インストール
#---------------------------------------------------------------------
#
.PHONY: xentools
xentools:
ifeq ($(OS),CentOS5)
	-mount /dev/xvdd /mnt
else
	-mount /dev/cdrom /mnt
endif
	-yes | /mnt/Linux/install.sh
#
#---------------------------------------------------------------------
# yum update
#---------------------------------------------------------------------
#
.PHONY: update
update:
	yum -y update
#
#---------------------------------------------------------------------
# git
#---------------------------------------------------------------------
#
LOCAL=/usr/local
LOCALSRC=$(LOCAL)/src
LOCALBIN=$(LOCAL)/bin
GITBIN=$(LOCALBIN)/git
GITSRC=$(LOCALSRC)/git
.PHONY:	git
git:	gitbin gitflow
	@echo "-----------------"
	@git --version
	@echo "-----------------"

.PHONY: gitbin
gitbin:	$(GITBIN)

$(GITBIN):	$(GITSRC)
	-yum -y install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-ExtUtils-MakeMaker gcc
	cd $(GITSRC); git fetch; git pull; $(MAKE) prefix=$(LOCAL) all install
	-yum -y remove git

.PHONY: gitsrc
gitsrc: $(GITSRC)

$(GITSRC):	/usr/bin/git
	mkdir -p $(GITSRC)
	git clone git://git.kernel.org/pub/scm/git/git.git /usr/local/src/git

/usr/bin/git:
	-yum -y install git
#
#---------------------------------------------------------------------
# git daily build
#---------------------------------------------------------------------
#
.PHONY: git_daily_build
git_daily_build:
	cd $(GITSRC); git fetch --all; git pull; $(MAKE) prefix=$(LOCAL) all install
	@echo "-----------------"
	@git --version
	@echo "-----------------"

GIT_SRC_HOST=gitlab.sion.co.jp
.PHONY: rsync_git_src
rsync_git_src:
	rsync -azv --delete $(EMACS_SRC_HOST):$(GITSRC) $(LOCALSRC)
#
#---------------------------------------------------------------------
# gitflow
#---------------------------------------------------------------------
#
GITFLOW_INST=gitflow-installer.sh
.PHONY: gitflow
gitflow: $(GITFLOW_INST)
	-git flow

$(GITFLOW_INST):
	-yum -y remove gitflow git
	curl -OL https://raw.githubusercontent.com/nvie/gitflow/develop/contrib/$(GITFLOW_INST)
	sed -i -e "s/http/https/" $(GITFLOW_INST)
	sh $(GITFLOW_INST)
	rm -rf gitflow
#
#---------------------------------------------------------------------
# emacs
#---------------------------------------------------------------------
#
.PHONY: emacs
emacs:
	$(MAKE) emacs25 dot.emacs.d
#
#---------------------------------------------------------------------
# emacs25
#---------------------------------------------------------------------
#
EMACSSRC=$(LOCALSRC)/emacs
EMACSBIN=$(LOCALBIN)/emacs
.PHONY: emacs25
emacs25: $(EMACSBIN)

$(EMACSBIN): autoconf $(EMACSSRC)
	-yum -y install automake ncurses-devel gnutls-devel
	cd $(EMACSSRC); ./autogen.sh
	cd $(EMACSSRC); ./configure --with-gnutls=no --without-x --without-makeinfo --without-sound --prefix=$(LOCAL)
	cd $(EMACSSRC); time $(MAKE); $(MAKE) install

$(EMACSSRC):
	$(GITBIN) clone git://git.sv.gnu.org/emacs.git $(EMACSSRC)

EMACS_SRC_HOST=gitlab.sion.co.jp
.PHONY: rsync_emacs_src
rsync_emacs_src:
	rsync -azv --delete $(EMACS_SRC_HOST):$(EMACSSRC) $(LOCALSRC)

AUTOCONF=autoconf2.68
AUTOCONF_TAZ=$(AUTOCONF).tar.bz2
AUTOCONF_SRCTAZ=$(LOCALSRC)/$(AUTOCONF_TAZ)
AUTOCONF_SRCDIR=$(LOCALSRC)/autoconf-2.68
AUTOCONF_BIN=$(LOCALBIN)/autoconf
.PHONY: autoconf
ifeq ($(OS),CentOS7)
autoconf:
	-yum -y install autoconf
else
autoconf: $(AUTOCONF_BIN)
endif
$(AUTOCONF_BIN): $(AUTOCONF_SRCDIR)
	cd $(AUTOCONF_SRCDIR); ./configure; $(MAKE); $(MAKE) install

$(AUTOCONF_SRCDIR): $(AUTOCONF_SRCTAZ)
	tar xf $(AUTOCONF_SRCTAZ) -C $(LOCALSRC)

$(AUTOCONF_SRCTAZ):
	-yum -y install wget
	wget ftp://ftp.gnu.org/gnu/autoconf/autoconf-2.68.tar.bz2 -O $(AUTOCONF_SRCTAZ)
#
#---------------------------------------------------------------------
# .emacs.d
#---------------------------------------------------------------------
#
.PHONY: dot.emacs.d
dot.emacs.d: ~/.emacs.d/.git

~/.emacs.d/.git:
	-rm -rf ~/.emacs ~/.emacs.d
	$(GITBIN) config --global credential.helper store
	$(GITBIN) clone http://gitlab.sion.co.jp/Net/.emacs.d.git ~/.emacs.d
#---------------------------------------------------------------------
# emacs 削除からの emacs インストール
#---------------------------------------------------------------------
#
.PHONY: emacs_force
emacs_force:
	-yum -y remove emacs*
	$(MAKE) emacs
#
#---------------------------------------------------------------------
# emacs 関連一括更新
#---------------------------------------------------------------------
#
.PHONY: emacs_force_all
emacs_force_all:
	-rm -rf ~/.emacs.d
	$(MAKE) dot.emacs.d emacs_force_update

.PHONY: emacs_force_update
emacs_force_update:
	-rm -rf $(EMACSBIN)
	-cd $(EMACSSRC); $(MAKE) distclean
	rsync -azv --delete gitlab.sion.co.jp:$(EMACSSRC) $(LOCALSRC)
	$(MAKE) autoconf emacs_pull emacs
#
#---------------------------------------------------------------------
# emacs pull
#---------------------------------------------------------------------
#
.PHONY: emacs_pull
emacs_pull:
	cd $(EMACSSRC); $(MAKE) clean; $(GITBIN) pull
#
#---------------------------------------------------------------------
# emacs daily build
#---------------------------------------------------------------------
#
.PHONY: emacs_daily_build
emacs_daily_build:
	cd $(EMACSSRC); $(GITBIN) fetch --all
	cd $(EMACSSRC); $(GITBIN) pull
	cd $(EMACSSRC); ./autogen.sh
	cd $(EMACSSRC); ./configure --without-x --without-makeinfo --without-sound --prefix=$(LOCAL)
	cd $(EMACSSRC); time $(MAKE); $(MAKE) install; $(MAKE) distclean
	@echo "----------------------------------------------------------"
	$(EMACSBIN) --version
	@echo "----------------------------------------------------------"
#
#-------------------------------------------------------------------------------
#
### Local Variables:			###
### compile-command: "make init"	###
### comment-column: 0			###
### comment-start: "### " 		###
### comment-end: "	###"		###
### End:				###
