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
	A("vps.vpn.pluralkit.net.", "100.77.37.109"),
	// todo: add beta

	/// services
	A("hashi.svc.pluralkit.net.", "100.77.37.109"), // vps
	A("db.svc.pluralkit.net.", "100.83.67.99"), // db2

	/// misc
	AAAA("dispatch.svc.pluralkit.net.", "fdaa:9:e856:0:1::2"),
END);
