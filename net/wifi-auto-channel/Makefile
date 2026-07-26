include $(TOPDIR)/rules.mk

PKG_NAME:=wifi-auto-channel
PKG_VERSION:=0.2.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Daniel Bankmann <daniel@dbankmann.de>
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/wifi-auto-channel
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Wireless
  DEPENDS:=+ucode +ucode-mod-ubus +ucode-mod-uci +ucode-mod-uloop +ucode-mod-nl80211 +ucode-mod-fs
  TITLE:=Automatic WiFi channel management
  PKGARCH:=all
endef

define Package/wifi-auto-channel/description
  Monitors WiFi channel utilization and automatically switches to less
  congested channels using CSA (Channel Switch Announcement). Supports
  all mac80211-based drivers, DFS channels, and VHT/HE channel widths.
endef

define Package/wifi-auto-channel/conffiles
/etc/config/wifi-auto-channel
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
	touch $(PKG_BUILD_DIR)/.built
endef

define Package/wifi-auto-channel/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/wifi-auto-channel.uc $(1)/usr/sbin/wifi-auto-channel
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/wifi-auto-channel.init $(1)/etc/init.d/wifi-auto-channel
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/wifi-auto-channel.config $(1)/etc/config/wifi-auto-channel
	$(INSTALL_DIR) $(1)/usr/share/ucode/wifi-auto-channel
	$(INSTALL_DATA) ./files/usr/share/ucode/wifi-auto-channel/channel.uc \
		$(1)/usr/share/ucode/wifi-auto-channel/channel.uc
endef

$(eval $(call BuildPackage,wifi-auto-channel))
