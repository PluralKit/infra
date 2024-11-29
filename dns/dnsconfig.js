var REG_NONE = NewRegistrar("none");
var DNS_CLOUDFLARE = NewDnsProvider("cloudflare");

// warning: parser for this file is ES5, new JS features are not supported
// update with `nix run nixpkgs#dnscontrol -- push --creds '!./creds.sh'`

// es5...
String.prototype.endsWith = function(search) {
	return search == this.substring(this.length - search.length, this.length)
}

var hosts = {
	"compute-hrhel1-3c45e932": [ "65.21.83.253", "100.125.28.89" ],
	"compute-hrhel1-70e1bd12": [ "65.108.12.49", "100.77.98.43" ],
	"database-hrhel1-b959773f": [ "95.217.79.59", "100.96.216.62" ],
	"hashi-hchel1-5fd89a52": [ "95.216.154.82", "100.120.65.72" ],
	"hashi-hchel1-5fd9b1fe": [ "95.217.177.254", "100.114.8.65" ],
	"hashi-hchel1-251b08ea": [ "37.27.8.234", "100.113.220.49" ],
};

var serviceHostMap = {
	"hashi": [
		"hashi-hchel1-5fd89a52",
		"hashi-hchel1-5fd9b1fe",
		"hashi-hchel1-251b08ea",
	],
	"db": ["database-hrhel1-b959773f"],
	"observability": ["database-hrhel1-b959773f"],
};

var argoTunnelDomain = "5fbeffbb-cdec-4d64-b5b7-63c1d6e2e9cd.cfargotunnel.com.";
var cfTunnels = [
	"logs.pluralkit.net.",
];

D.apply(null, Array.prototype.concat(
	// meta
	["pluralkit.net", REG_NONE, DnsProvider(DNS_CLOUDFLARE)],

	// hosts
	Object.keys(hosts).map(function (host) {
		return [
			A(host+".prod.pluralkit.net.", hosts[host][0]),
			A(host+".vpn.pluralkit.net.", hosts[host][1]),
		]
	}),

	// cloudflare tunnel records
	cfTunnels.map(function (t) { return [ CNAME(t, argoTunnelDomain) ] }),

	// services
	Array.prototype.concat(Object.keys(serviceHostMap).map(function (svc) {
		return serviceHostMap[svc].map(function (target) {
			var type;
			var value;
			if (target.endsWith(".")) {
				type = CNAME;
				value = target;
			} else {
				type = A;
				value = hosts[target][1];
			}
			return type(svc+".svc.pluralkit.net.", value);
		})
	})),

	// manual records
	[
		// legacy
		A("db2.pluralkit.net.", "148.251.178.57"),
		A("db2.vpn.pluralkit.net.", "100.83.67.99"),
		A("vps.pluralkit.net.", "162.55.174.253"),
		A("vps.vpn.pluralkit.net.", "100.77.37.109"),

		// todo: add beta

		/// services
		AAAA("dispatch.svc.pluralkit.net.", "fdaa:9:e856:0:1::3"),
	],
	[END]
));

D("pluralkit.me", REG_NONE, DnsProvider(DNS_CLOUDFLARE),
	// web
	ALIAS("@", "apex-loadbalancer.netlify.com."),
	CNAME("www", "apex-loadbalancer.netlify.com."),
	CNAME("cdn", "f003.backblazeb2.com.", CF_PROXY_ON),
	A("*", "162.55.174.253"),
	AAAA("*", "2a01:4f8:1c17:f925::1"),

	// beta
	A("beta.pluralkit.me.", "168.119.255.71"),
	AAAA("beta.pluralkit.me.", "2a01:4f8:1c17:e154::1"),
	A("*.beta.pluralkit.me.", "168.119.255.71"),
	AAAA("*.beta.pluralkit.me.", "2a01:4f8:1c17:e154::1"),
	CNAME("beta.dash.pluralkit.me.", "beta.pluralkit.me."),

	// email
	MX("@", 10, "in1-smtp.messagingengine.com."),
	MX("@", 20, "in2-smtp.messagingengine.com."),
	TXT("@", "v=spf1 include:spf.messagingengine.com ?all"),
	CNAME("fm1._domainkey.pluralkit.me.", "fm1.pluralkit.me.dkim.fmhosted.com."),
	CNAME("fm2._domainkey.pluralkit.me.", "fm2.pluralkit.me.dkim.fmhosted.com."),
	CNAME("fm3._domainkey.pluralkit.me.", "fm3.pluralkit.me.dkim.fmhosted.com."),
END)
