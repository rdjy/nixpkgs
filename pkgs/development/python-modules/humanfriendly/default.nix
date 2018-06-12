{ lib, buildPythonPackage, fetchPypi, libyaml }:

buildPythonPackage rec {
  pname = "humanfriendly";
  version = "4.12.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "18qjl58xiicgydfpxaap6gxinm19jibj7axw7q10g46jk4n4sywk";
  };

  doCheck = false;

  meta = with lib; {
    description = "Human friendly output for text interfaces using Python";
    homepage = https://humanfriendly.readthedocs.io/;
    license = licenses.mit;
  };
}
