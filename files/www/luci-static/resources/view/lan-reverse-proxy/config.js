'use strict';
'require form';
'require rpc';
'require uci';
'require ui';
'require view';

var callInterfaceDump = rpc.declare({
	object: 'network.interface',
	method: 'dump',
	expect: { interface: [] }
});

var callRcList = rpc.declare({
	object: 'rc',
	method: 'list',
	expect: { '': {} }
});

var callRcInit = rpc.declare({
	object: 'rc',
	method: 'init',
	params: [ 'name', 'action' ]
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('lan_reverse_proxy'),
			callInterfaceDump(),
			callRcList()
		]);
	},

	handleAction: function(action) {
		return callRcInit('lan-reverse-proxy', action).then(function(ret) {
			if (ret)
				throw _('Command failed');
			window.location.reload();
		}).catch(function(err) {
			ui.addNotification(null, E('p', _('Unable to execute service action: %s').format(err)));
		});
	},

	render: function(data) {
		var self = this;
		var interfaces = Array.isArray(data[1]) ? data[1] : [];
		var initList = data[2] || {};
		var service = initList['lan-reverse-proxy'] || {};
		var m = new form.Map('lan_reverse_proxy', _('LAN Reverse Proxy'), _('Saving changes reloads a running proxy without terminating established streams.'));
		var main = m.section(form.NamedSection, 'main', 'lan_reverse_proxy', _('Proxy settings'));

		var listenPort = main.option(form.Value, 'listen_port', _('Local HTTP port'));
		listenPort.datatype = 'port';
		listenPort.default = '5665';
		listenPort.rmempty = false;

		var allowed = main.option(form.MultiValue, 'interfaces', _('Allowed network interfaces'));
		allowed.description = _('Requests are allowed from the current subnets of the selected interfaces. LAN is selected by default.');
		allowed.rmempty = false;
		var interfaceNames = {};
		interfaces.forEach(function(iface) {
			if (iface.interface && iface.interface !== 'loopback') {
				allowed.value(iface.interface, iface.interface);
				interfaceNames[iface.interface] = true;
			}
		});
		if (!interfaceNames.lan)
			allowed.value('lan', 'lan');

		var active = main.option(form.ListValue, 'active_server', _('Active upstream'));
		active.description = _('Add and save an upstream profile before selecting it here.');
		active.value('', _('Not selected'));
		uci.sections('lan_reverse_proxy', 'upstream').forEach(function(upstream) {
			active.value(upstream['.name'], upstream.label || upstream['.name']);
		});

		var servers = m.section(form.TypedSection, 'upstream', _('Upstream profiles'));
		servers.addremove = true;
		servers.anonymous = true;

		var label = servers.option(form.Value, 'label', _('Name'));
		label.rmempty = false;

		var scheme = servers.option(form.ListValue, 'scheme', _('Protocol'));
		scheme.value('http', 'HTTP');
		scheme.value('https', 'HTTPS');
		scheme.default = 'https';
		scheme.rmempty = false;

		var host = servers.option(form.Value, 'host', _('Hostname or IPv4 address'));
		host.rmempty = false;
		host.validate = function(sectionId, value) {
			if (!value)
				return _('A hostname or IPv4 address is required.');
			var labels = value.split('.');
			for (var i = 0; i < labels.length; i++)
				if (!/^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(labels[i]))
					return _('Enter a hostname or IPv4 address without a scheme, path, or port.');
			return true;
		};

		var port = servers.option(form.Value, 'port', _('Port'));
		port.datatype = 'port';
		port.rmempty = false;

		var username = servers.option(form.Value, 'username', _('Basic Auth username'));
		username.rmempty = true;

		var password = servers.option(form.Value, 'password', _('Basic Auth password'));
		password.password = true;
		password.rmempty = true;
		password.description = _('Leave both authentication fields empty to disable Basic Auth.');
		function validateAuth(sectionId) {
			var user = username.formvalue(sectionId);
			var pass = password.formvalue(sectionId);
			if (user && user.indexOf(':') !== -1)
				return _('The username cannot contain a colon.');
			if (!!user !== !!pass)
				return _('Enter both Basic Auth fields or leave both empty.');
			return true;
		}
		username.validate = validateAuth;
		password.validate = validateAuth;

		return m.render().then(function(map) {
			var status = service.running ? _('Running') : _('Stopped');
			var autostart = service.enabled ? _('Enabled') : _('Disabled');
			var actions = E('div', { 'class': 'cbi-section' }, [
				E('h3', _('Service control')),
				E('p', _('Current status: %s; start at boot: %s').format(status, autostart)),
				E('button', {
					'type': 'button',
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(self, 'handleAction', service.running ? 'stop' : 'start')
				}, service.running ? _('Stop') : _('Start')),
				' ',
				E('button', {
					'type': 'button',
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(self, 'handleAction', service.enabled ? 'disable' : 'enable')
				}, service.enabled ? _('Disable autostart') : _('Enable autostart'))
			]);
			return E('div', {}, [ actions, map ]);
		});
	}
});
