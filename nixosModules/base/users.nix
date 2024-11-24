{ pkgs
, lib
, inputs
, ...
}:

with lib;

let
  userList = [
    { name = "iris"; uid = 1001; }
    { name = "astrid"; uid = 1002; }
    { name = "alyssa"; uid = 1004; }
  ];

  mkUserDesc = user: {
    inherit (user) uid;
    isNormalUser = true;
    extraGroups = [ "wheel" "systemd-journal" ];
    openssh.authorizedKeys.keys =
      (splitString "\n" (readFile ../../sshKeys/${user.name}));
  };

in
{
  users.mutableUsers = false;
  users.users =
    listToAttrs (map (user: nameValuePair user.name (mkUserDesc user)) userList) //
      {
        root = {
          initialHashedPassword = "";
          openssh.authorizedKeys.keys =
            (flatten (map (user: (mkUserDesc user).openssh.authorizedKeys.keys) userList));
        };
      };
}
