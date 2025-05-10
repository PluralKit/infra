var REG_NONE = NewRegistrar("none");
var DNS_CLOUDFLARE = NewDnsProvider("cloudflare");

// warning: parser for this file is ES5, new JS features are not supported
// update with `nix run nixpkgs#dnscontrol -- push --creds '!./creds.sh'`

// es5...
String.prototype.endsWith = function(search) {
	return search == this.substring(this.length - search.length, this.length)
}

var hosts = {
	"database-hrhel1-251b75a5": [ "37.27.117.165", "100.115.185.127" ],
	"utils-hcash1-05a12be2": [ "5.161.43.226", "100.79.33.60" ],
};

var serviceHostMap = {};

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
		A("anycast.pluralkit.net.", "37.16.30.32"),
		AAAA("anycast.pluralkit.net.", "2a09:8280:1::6e:4cd4:0"),

		CNAME("packages.pluralkit.net.", "public.r2.dev.", CF_PROXY_ON),

		/// services
		AAAA("dispatch.svc.pluralkit.net.", "fdaa:9:e856:0:1::3"),

    // observability
    AAAA("vm.svc.pluralkit.net.", "fdaa:9:e856:0:1::4"),
    AAAA("alerts.svc.pluralkit.net.", "fdaa:9:e856:0:1::5"),
    AAAA("es.svc.pluralkit.net.", "fdaa:9:e856:0:1::6"),
    AAAA("logs.pluralkit.net.", "fdaa:9:e856:0:1::7"),
    AAAA("grafana.pluralkit.net.", "fdaa:9:e856:0:1::8"),

    // oob
    A("node1.oob.pluralkit.net.", "192.168.255.101"),
    A("sw01.oob.pluralkit.net.", "192.168.255.102"),
    A("node2.oob.pluralkit.net.", "192.168.255.103"),
    A("router1.oob.pluralkit.net.", "192.168.255.104"),
    A("sw02.oob.pluralkit.net.", "192.168.255.105"),
    A("node3.oob.pluralkit.net.", "192.168.255.106"),
    A("node4.oob.pluralkit.net.", "192.168.255.107"),
	],
	[END]
));

var anycastSubdomains = [
	"www",
	"cdn",
	"api",
	"dash",
	"grafana",
	"gt",
	"stats",
];

D("pluralkit.me", REG_NONE, DnsProvider(DNS_CLOUDFLARE),
	TXT("@", "google-site-verification=LaVKTs1MvdA4MLaHV_3hUlR1aOVKqfjWzaBWNlGVblE"),

	// web
	ALIAS("@", "anycast.pluralkit.net."),

	CNAME("_acme-challenge", "pluralkit.me.enqnew.flydns.net."),

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
