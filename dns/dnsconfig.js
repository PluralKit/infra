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
	"compute-hchel1-416cf81b": [ "65.108.248.27", "100.109.78.112" ],
	"database-hrhel1-b959773f": [ "95.217.79.59", "100.96.216.62" ],
	"edge-vlsto-4622d8e3": [ "70.34.216.227", "100.120.109.26" ],
	"edge-vlsto-4622d978": [ "70.34.217.120", "100.125.209.95" ]
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
	"nomad.pluralkit.net.",
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
	cfTunnels.map(function (t) { return [ CNAME(t, argoTunnelDomain, CF_PROXY_ON) ] }),

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
		A("anycast.pluralkit.net.", "70.34.215.108"),
		AAAA("anycast.pluralkit.net.", "2a05:f480:2000:2894::"),

		CNAME("packages.pluralkit.net.", "public.r2.dev.", CF_PROXY_ON),

		/// services
		AAAA("dispatch.svc.pluralkit.net.", "fdaa:9:e856:0:1::3"),

    // observability
    AAAA("vm.svc.pluralkit.net.", "fdaa:9:e856:0:1::4"),
    AAAA("alerts.svc.pluralkit.net.", "fdaa:9:e856:0:1::5"),
    AAAA("es.svc.pluralkit.net.", "fdaa:9:e856:0:1::6"),
    AAAA("newlogs.pluralkit.net.", "fdaa:9:e856:0:1::7"),
    AAAA("grafana.pluralkit.net.", "fdaa:9:e856:0:1::8"),
	],
	[END]
));

var anycastSubdomains = [
	"www",
	"api",
	"dash",
	"grafana",
	"gt",
	"stats",
];

D("pluralkit.me", REG_NONE, DnsProvider(DNS_CLOUDFLARE),
	TXT("@", "google-site-verification=LaVKTs1MvdA4MLaHV_3hUlR1aOVKqfjWzaBWNlGVblE"),

	// web
	ALIAS("@", "apex-loadbalancer.netlify.com."),
	CNAME("cdn", "f003.backblazeb2.com.", CF_PROXY_ON),

	anycastSubdomains.map(function (t) { return [
		CNAME(t+".pluralkit.me.", "anycast.pluralkit.net.")
	] }),

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
