{ stdenv, buildPythonPackage, fetchPypi, pytest, aiohttp }:

buildPythonPackage rec {
  pname = "pytest-aiohttp";
  version = "0.3.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0kx4mbs9bflycd8x9af0idcjhdgnzri3nw1qb0vpfyb3751qaaf9";
  };

  propagatedBuildInputs = [ pytest aiohttp ];

  meta = with stdenv.lib; {
    homepage = https://github.com/aio-libs/pytest-aiohttp/;
    description = "Pytest plugin for aiohttp support";
    license = licenses.asl20;
    maintainers = with maintainers; [ dotlambda ];
  };
}