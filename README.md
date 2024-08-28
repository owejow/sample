# Custom Modules for devenv.sh

This repository provides additional custom modules for
[devenv.sh](https://github.com/cachix/devenv). The builtin modules provide an
extensive set of languages, processes and services. This module defines a range
of services that are not covered in the standard release.

## Usage

The imports declaration in deven.nix can be used to gain access to these modules.

The steps involved are the following:

1. add the link in this repository to devenv.yaml

```nix
# add devenv-extras url underneath the inputs section of devenv.yaml
inputs:
  devenv-extras:
    url: github:owejow/devenv-extras
    flake: false
```

2. use the imports declaration to load the modules in devenv.nix

```nix
  # add the imports declaration inside devenv.nix
  { pkgs, lib, inputs, config, ... }: {
    imports = [ inputs.devenv-extras.outPath ];
    # rest of devenv.nix
    # ...
    # ...
  }
```

3. Use the options provided in deven-extras to suit your needs.

## Provided options

### [Phoenix Framework Options](https://www.phoenixframework.org/)

- phoenix.services.enable : Add phoenix mock process.

  - Type: boolean
  - Default: false
  - Example: true

- phoenix.services.db_role : Postgres database role to use

  - Type: string
  - Default: "postgres"
  - Example: "myrole"

- phoenix.services.db_password : Postgres password to use
  - Type: string
  - Default: "postgres"
  - Example: "mypassword"

### [stripe-mock](https://github.com/stripe/stripe-mock)

- stripe-mock.services.enable : Add stripe mock process.

  - Type: boolean
  - Default: false
  - Example: true

- stripe-mock.services.package : The stripe-mock version to use

  - Type: package
  - Default: uses GoModule to select version 0.182.0 (declared in ./modules/stripe-mock/stripe-mock.nix)

- stripe-mock.services.listen_address : listen address for stripe-mock server. By default it listens in on all IP addresses.

  - Type: String
  - Default: "" # listens in on all IP addresses
  - Example: "127.0.0.1"

- stripe-mock.services.http_port : http_port to listen on

  - type: port
  - default: 12111
  - example: 4141

- stripe-mock.services.https_port : https_port to listen on

  - type: port
  - default: 12112
  - example: 3131

### [zola](https://getzola.org)

- zola.services.open : open browser automatically to zola url

  - Type: boolean
  - Default: false
  - Example: true

- zola.services.package : The zola package to use

  - Type: package
  - Default: uses pkgs.zola from nixpkgs
