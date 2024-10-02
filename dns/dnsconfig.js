var REG_NONE = NewRegistrar("none");
var DNS_HE = NewDnsProvider("hedns");

// update with `nix run nixpkgs#dnscontrol -- push --creds '!./creds.sh'`

D("pluralkit.net", REG_NONE, DnsProvider(DNS_HE),
	/// hosts
	A("compute03.pluralkit.net.", "116.202.146.157"),
	A("compute03.vpn.pluralkit.net.", "100.100.251.99"),
	A("db2.pluralkit.net.", "148.251.178.57"),
	A("db2.vpn.pluralkit.net.", "100.83.67.99"),
	A("vps.pluralkit.net.", "162.55.174.253"),
	A("vps.vpn.pluralkit.net.", "100.99.134.112"),
	A("manage-tmp.pluralkit.net.", "188.34.156.231"),
	A("manage-tmp.vpn.pluralkit.net.", "100.86.170.19"),
	A("manage-tmp2.pluralkit.net.", "188.245.126.196"),
	A("manage-tmp2.vpn.pluralkit.net.", "100.82.64.16"),
	// todo: add beta

	/// hashi
	A("hashi.svc.pluralkit.net.", "100.86.170.19"), // manage-tmp
	A("hashi.svc.pluralkit.net.", "100.99.134.112"), // manage-tmp2

	/// misc
	AAAA("dispatch.svc.pluralkit.net.", "fdaa:9:e856:0:1::2"),
END);
