# clean generate IP cores files, but the source ones (.tcl)
clean::
	$(foreach ipcore, $(dsbpm_IP_CORES), test -f $(dsbpm_zu48_platform_app_DIR)/$(ipcore)/$(ipcore).tcl && find $(dsbpm_zu48_platform_app_DIR)/$(ipcore) -mindepth 1 -not \( -name \*$(ipcore).tcl -o -name \*.coe \) -delete $(CMD_SEP))
	$(foreach bd, $(dsbpm_BD_CORE), test -f $(dsbpm_zu48_platform_app_DIR)/$(bd)/$(bd).tcl && find $(dsbpm_zu48_platform_app_DIR)/$(bd) -mindepth 1 -not \( -name \*$(bd).tcl -o -name \*.coe \) -delete $(CMD_SEP))
