#!/bin/sh

export OPAMUTF8MSGS=true
sudo add-apt-repository --yes ppa:avsm/ppa
sudo apt-get update
sudo apt-get install --yes ttf-ancient-fonts opam m4 libpcre3-dev libssl-dev zlib1g-dev
opam init --auto-setup
eval `opam config env`
opam switch --yes 4.01.0
eval `opam config env`
opam install --yes ocamlfind extlib calendar pcre pgocaml camlzip ssl cryptokit ocamlnet json-wheel json-static sha ocamldap cppo camlmix caml2html easy-format biniou yojson menhir merlin type_conv ocaml-data-notation ocamlmod ocamlify fileutils expect ounit oasis
