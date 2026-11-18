.PHONY: install verify uninstall rea-install rea-verify rea-uninstall egm-install egm-verify egm-uninstall

install: rea-install egm-install

verify: rea-verify egm-verify

uninstall: egm-uninstall rea-uninstall

rea-install:
	bash rea/scripts/install.sh

rea-verify:
	bash rea/scripts/verify.sh

rea-uninstall:
	bash rea/scripts/uninstall.sh

egm-install:
	bash egm/scripts/install.sh

egm-verify:
	bash egm/scripts/verify.sh

egm-uninstall:
	bash egm/scripts/uninstall.sh
