include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-lan-reverse-proxy
PKG_VERSION:=0.1.0
PKG_RELEASE:=5
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-lan-reverse-proxy
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LAN Reverse Proxy
  DEPENDS:=+luci-base +nginx-ssl +ca-bundle +coreutils-base64
  PKGARCH:=all
endef

define Package/luci-app-lan-reverse-proxy/description
  Configures a lightweight LAN HTTP reverse proxy for manually selected HTTP or HTTPS upstreams.
endef

define Package/luci-app-lan-reverse-proxy/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/lib/lan-reverse-proxy
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/lan-reverse-proxy
	$(INSTALL_CONF) ./files/etc/config/lan_reverse_proxy $(1)/etc/config/lan_reverse_proxy
	$(INSTALL_BIN) ./files/etc/init.d/lan-reverse-proxy $(1)/etc/init.d/lan-reverse-proxy
	$(INSTALL_BIN) ./files/usr/lib/lan-reverse-proxy/generate-config $(1)/usr/lib/lan-reverse-proxy/generate-config
	$(INSTALL_DATA) ./files/usr/share/luci/menu.d/luci-app-lan-reverse-proxy.json $(1)/usr/share/luci/menu.d/luci-app-lan-reverse-proxy.json
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-app-lan-reverse-proxy.json $(1)/usr/share/rpcd/acl.d/luci-app-lan-reverse-proxy.json
	$(INSTALL_DATA) ./files/www/luci-static/resources/view/lan-reverse-proxy/config.js $(1)/www/luci-static/resources/view/lan-reverse-proxy/config.js
endef

$(eval $(call BuildPackage,luci-app-lan-reverse-proxy))
