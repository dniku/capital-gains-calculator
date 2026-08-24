{
  lib,
  fetchFromGitHub,
  fetchPypi,
  python3Packages,
  ruff,
  rustPlatform,
  texliveSmall,
  src,
  version,
}:

let
  pythonCheckPaths = lib.escapeShellArgs [
    "cgt_calc"
    "tests"
    "scripts"
  ];

  # These two stubs are missing from nixpkgs. Derive their packaging from its
  # types-colorama package: the same typeshed source layout and setuptools build.
  extraTypeStubs =
    map
      (
        source:
        python3Packages.types-colorama.overridePythonAttrs (oldAttrs: {
          inherit (source) pname version;
          src = fetchPypi source;
          meta = oldAttrs.meta // {
            description = "Typing stubs for ${source.pname}";
          };
        })
      )
      [
        {
          pname = "types_defusedxml";
          version = "0.7.0.20260504";
          hash = "sha256-KrKCij+XERuhwWzuJzrUEkqDH8kZjEG/g2j/bqSK0wA=";
        }
        {
          pname = "types_reportlab";
          version = "5.0.0.20260911";
          hash = "sha256-QKoahv6MFChWcMu1mKZB07nd5ZqPfC7LJFuMSPFdTWw=";
        }
      ];

  shtab = python3Packages.shtab.overridePythonAttrs (
    finalAttrs: oldAttrs: {
      version = "1.12.1";
      src = fetchPypi {
        inherit (finalAttrs) pname version;
        hash = "sha256-BjczhyOo/AjtHC/YJthDIimSRknCbjJHu0jFPWDKO/k=";
      };
      nativeCheckInputs = oldAttrs.nativeCheckInputs ++ [ python3Packages.click ];
    }
  );

  yfinance = python3Packages.yfinance.overridePythonAttrs (
    finalAttrs: _: {
      version = "1.7.0";
      src = fetchFromGitHub {
        owner = "ranaroussi";
        repo = "yfinance";
        tag = finalAttrs.version;
        hash = "sha256-nM6vpxMZmPAw+aNg3U3/zvQ6I8Tzv0gM2IkadexJMC0=";
      };
    }
  );

  uvBuild = python3Packages.uv-build.overridePythonAttrs (
    finalAttrs: _: {
      version = "0.12.22";
      src = fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        tag = finalAttrs.version;
        hash = "sha256-lgGB9kO3+xnm1Tob+PflpiZRLW7a6Gvim3qVKc6JceY=";
      };
      cargoDeps = rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = "sha256-IC7rbCcUf7U33pNGZRfHLeXAcTLIYJJ6iSj9LFcWIy4=";
      };
    }
  );
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "cgt-calc";
  inherit src version;
  pyproject = true;

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'version = "0.0.0"' 'version = "${finalAttrs.version}"'
  '';

  build-system = [ uvBuild ];

  # Upstream's pandas floor rose through Dependabot-only changes. nixpkgs
  # packages 3.0.4; no API change relies on the bumps, and the full suite below
  # checks compatibility rather than overriding pandas and its dependants.
  pythonRelaxDeps = [ "pandas" ];

  dependencies = with python3Packages; [
    colorama
    defusedxml
    jinja2
    openpyxl
    pandas
    pdfplumber
    pyrate-limiter
    requests
    shtab
    xlrd
    yfinance
  ];

  nativeCheckInputs =
    extraTypeStubs
    ++ (with python3Packages; [
      mypy
      packaging
      pandas-stubs
      pytestCheckHook
      pytest-env
      pytest-xdist
      reportlab
      ruff
      texliveSmall
      types-colorama
      types-python-dateutil
      types-requests
    ]);

  env.CGT_TEST_MODE_STRICT = "1";
  env.ENABLE_PDFLATEX = "1";

  preCheck = ''
    # pdfTeX caches generated fonts; the Nix builder has no writable home.
    export TEXMFVAR="$TMPDIR/texmf-var"
    ruff format --check ${pythonCheckPaths}
    ruff check ${pythonCheckPaths}
    # Avoid the mypy worker-process stall in the Nix build environment.
    mypy --num-workers 0 ${pythonCheckPaths}
  '';

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${lib.getBin texliveSmall}/bin"
  ];

  pythonImportsCheck = [ "cgt_calc" ];

  meta = {
    description = "UK capital gains tax calculator";
    homepage = "https://github.com/cgt-calc/capital-gains-calculator";
    license = lib.licenses.mit;
    mainProgram = "cgt-calc";
  };
})
