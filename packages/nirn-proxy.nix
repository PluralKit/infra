{
  pkgs,
  fetchgit
}:

pkgs.buildGoModule rec {
  name = "nirn-proxy";
  vendorHash = "sha256-vggC3pZmT3hProXQyudAh0K1GFJRfuoOAZTENLct7N8=";
  src = fetchgit {
    url = "https://github.com/germanoeich/nirn-proxy";
    rev = "23fc2e790b136134283a985c4b779ecc1ba389f4";
    hash = "sha256-QjOmamJPBEgjoytPLEMCcWr3SVgK4PhC+2c1gHqNr60=";
  };
}
