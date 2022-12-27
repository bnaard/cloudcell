# How to setup a local VSCode development environment for a multi-tier-application

## Abstract

This article explains how to setup a VSCode development environment on a local machine to develop all tiers of a cloud-native application. The underlying scenario is a developer or a small team of developers of a small web-app, where each team member shall be able to run the full application stack (reverse proxy, frontend webserver, application server, database server) locally during development. The development environment uses [minikube](https://minikube.sigs.k8s.io).

VSCode development

Why local?

## What is a multi-tier-application?

```mermaid
flowchart LR
    user[User] <--> rp[Reverse Proxy \n Load Balancer]
    rp <-->|'/*'| ws[Web frontend server];
    rp <-->|'/api/*'| as[Application Server];
    ws <--> as
    as <--> dbs[(Database Server)];
```

This documentation is based on the following [Example App](https://github.com/hbollon/k8s-voting-app-aws/tree/main/k8s-specifications).

## Prerequisites

In your projects' folder, check out the remote git-repository:

```bash
git clone https://github.com/bnaard/cloudcell-stack.git
```

Then switch into current development branch (here as an example the branch `dev-0.0.0`):

```bash
cd cloudcell-stack
git checkout dev-0.0.0 
```

### Project directory structure

```text
├── cloucell-stack
│   ├── devenv-pod.yaml
│   ├── database-server.env
│   ├── 
│   ├── frontend-webserver   <-- folder for source code of web frontend (VSCode workspace)
│   │   ├── .devcontainer    <-- VSCode relevant folder with workspace description
│   │   │   ├── Dockerfile
│   │   │   ├── devcontainer.json
│   │   ├── ...
│   ├── application-server   <-- folder for source code of application backend (VSCode workspace) 
│   │   ├── .devcontainer    <-- VSCode relevant folder with workspace description
│   │   │   ├── Dockerfile
│   │   │   ├── devcontainer.json
│   │   ├── application-server <-- folder for python source-code (module)
│   │   │   ├── __init__.py
│   │   ├── docs             
│   │   ├── tests            <-- unit tests for application server
│   │   ├── .venv            <-- python virtual environment (development)
│   │   ├── pyproect.toml    <-- python poetry configuration file 
│   ├── database-server      <-- folder with local database storage (files)
│   │   ├── ...
│   ├── Docker               <-- all container images for development and production deployment (not for dev-build environment)
│   │   ├── dev
│   │   │   ├── frontend-webserver.Dockerfile
│   │   │   ├── application-server.Dockerfile

│   │   ├── prod
│   │   │   ├── frontend-webserver.Dockerfile
│   │   │   ├── application-server.Dockerfile

│   ├── helm                 <-- folder with helm templates and configuration values
│   │   ├── cloudcell-stack
│   │   │   ├── Chart.yaml
│   │   │   ├── values-prod.yaml  <-- configuration values for production deployments
│   │   │   ├── values-dev.yaml   <-- configuration values for local development deployment
│   │   │   ├── .helmignore
│   │   │   ├── templates
│   │   │   │   ├── app-ingress.yaml
│   │   │   │   ├── app-namespace.yaml
│   │   │   │   ├── application-server-deploy.yaml
│   │   │   │   ├── application-server-service.yaml
│   │   │   │   ├── frontend-webserver-deploy.yaml
│   │   │   │   ├── frontend-webserver-service.yaml
│   │   │   │   ├── database-deploy.yaml
│   │   │   │   ├── database-service.yaml
```

Start minikube Kubernetes cluster

```bash
minikube start
minikube status
kubectl get pods -A
minikube addons enable ingress
```

Clean up docker: remove dangling images. If you want to delete all images not currently used by containers, append `-a`.

```bash
docker image prune
```

## Configure docker

Use the `minikube docker-env` command that outputs environment variables needed to point the local Docker daemon to the minikube internal Docker registry:
[Ref](https://medium.com/swlh/how-to-run-locally-built-docker-images-in-kubernetes-b28fbc32cc1d)

```bash
eval $(minikube -p minikube docker-env)
```

## Create container images for development deployment

### Application server

docker-file for application server: `Docker/dev/application-server.Dockerfile`

```dockerfile
FROM python:3.10.2-slim
RUN /usr/local/bin/python3 -m pip install --upgrade pip
RUN useradd -ms /bin/bash -u 1001 applicationserver
USER applicationserver
WORKDIR /home/applicationserver   
ENV PATH=/home/applicationserver/.local/bin/:$PATH
```

```bash
docker build -f ./Docker/dev/application-server.Dockerfile -t application-server-dev .
```

## Frontend webserver

```dockerfile
FROM alpine:3.15.0
RUN apk update
RUN apk add --update npm
RUN apk add nodejs
```

```bash
docker build -f ./Docker/dev/frontend-webserver.Dockerfile -t frontend-webserver-dev .
```

## Namespace

Create new namespace for all elements of the development deployment and set it as default:

```bash
kubectl create namespace cloudcell-stack-dev
kubectl config set-context $(kubectl config current-context) --namespace cloudcell-stack-dev
```

## Secrets

Create `database-server.env` and secrets
[Xxx](https://stackoverflow.com/questions/64872206/create-kubernetes-env-var-secrets-from-env-file)

```bash
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<some_password>
POSTGRES_DB=cloudcell-db
POSTGRES_HOST_AUTH_METHOD=trust
```

```bash
kubectl create secret generic database-server-env --from-env-file=database-server.env
```

Verify secret

```bash
kubectl get secret database-server-env -o yaml
```

## Deployment

Update Helm repositories and download dependencies:

```bash
helm dependency update ./helm/cloudcell-stack
```

Potentially debug the Helm Charts:

```bash
helm lint ./helm/cloudcell-stack
helm template --debug cloudcell-stack ./helm/cloudcell-stack
```

Deploy the Helm Chart:

```bash
helm template cloudcell-stack ./helm/cloudcell-stack -f ./helm/cloudcell-stack/values-dev.yaml | kubectl apply -f -
```

## Check Deployment

Get your cluster IP:

```bash
minikube ip
```

List pods

```bash
kubectl get pods -A
```

You can keep an eye on the pod being created with:

```bash
kubectl get pods -A --watch
```

Check POD debug logs

```bash
kubectl describe --namespace=cloudcell-stack pod <name-from-get-pods-A>
kubectl logs --previous --tail 10 --namespace=cloudcell-stack -p <name>
```

## Destroy deployment

To stop and destroy all k8s deployed resources run:

```bash
helm template cloudcell-stack ./helm/cloudcell-stack --namespace=cloudcell-stack | kubectl delete -f -
minikube stop
```

## Find user and group IDs

```bash
kubectl exec -it $(kubectl get pods | grep "application-server" | awk '{print $1;}') -c application-server-container -- id
```

!!! note ""
    TBD minikube tunnel ??
    Nachdem das Addon aktiviert wurde, führen Sie bitte "minikube tunnel" aus, dann sind ihre Resourcen über "127.0.0.1" erreichbar

## Application server VSCode Development Environment

Open the `application-server` folder in VSCode with the function "Open in Container...". The first time, the container is opened, choose the following initial options:

- Python 3.9 (OS "bullseye" at the time of writing)
- no nodejs environment
- no other additional software added to the image

Then set up the main configuration files of VS Code as follows and run "Rebuild Container...".

Dockerfile for VSCode:

```Dockerfile
ARG VARIANT="3.10-bullseye"
FROM mcr.microsoft.com/vscode/devcontainers/python:0-${VARIANT}

RUN pip install poetry
RUN poetry config virtualenvs.create true
RUN poetry config virtualenvs.in-project true
```

devcontainer.json

```python
{
    "name": "Python 3",
    "build": {
        "dockerfile": "Dockerfile",
        "context": "..",
        "args": { 
            // Update 'VARIANT' to pick a Python version: 3, 3.10, 3.9, 3.8, 3.7, 3.6
            // Append -bullseye or -buster to pin to an OS version.
            // Use -bullseye variants on local on arm64/Apple Silicon.
            "VARIANT": "3.9-bullseye",
            // Options
            "NODE_VERSION": "none"
        }
    },

    // Set *default* container specific settings.json values on container create.
    "settings": { 
        "python.defaultInterpreterPath": "/usr/local/bin/python",
        "python.linting.enabled": true,
        "python.linting.pylintEnabled": true,
        "python.formatting.autopep8Path": "/usr/local/py-utils/bin/autopep8",
        "python.formatting.blackPath": "/usr/local/py-utils/bin/black",
        "python.formatting.yapfPath": "/usr/local/py-utils/bin/yapf",
        "python.formatting.provider": "black",
        "python.linting.banditPath": "/usr/local/py-utils/bin/bandit",
        "python.linting.flake8Path": "/usr/local/py-utils/bin/flake8",
        "python.linting.mypyPath": "/usr/local/py-utils/bin/mypy",
        "python.linting.pycodestylePath": "/usr/local/py-utils/bin/pycodestyle",
        "python.linting.pydocstylePath": "/usr/local/py-utils/bin/pydocstyle",
        // don't set path explicitly but rely on `python -m pylint` working so that
        // it finds pylint in currently active virtualenv
        // https://stackoverflow.com/questions/60030017/vscode-path-to-the-pylint-linter-is-invalid
        // "python.linting.pylintPath": "/usr/local/py-utils/bin/pylint",
        "editor.bracketPairColorization.enabled": true,
        "editor.guides.bracketPairs":"active",
    },

    // Add the IDs of extensions you want installed when the container is created.
    "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-azuretools.vscode-docker",
        "tamasfe.even-better-toml",
        "eamodio.gitlens",
        "davidanson.vscode-markdownlint",
        "humao.rest-client",
        "gruntfuggly.todo-tree",
        "redhat.vscode-yaml",
        "bierner.markdown-mermaid"
    ],

    // Use 'forwardPorts' to make a list of ports inside the container available locally.
    "forwardPorts": [8000],

    // Use 'postCreateCommand' to run commands after the container is created.
    // setc poetry configuration to creating virtual enviornment in project directory (ie on host file system)
    "postCreateCommand": "poetry config virtualenvs.create true && poetry config virtualenvs.in-project true",

    // Comment out connect as root instead. More info: https://aka.ms/vscode-remote/containers/non-root.
    "remoteUser": "vscode"
}
```

## Build Tool

### General

The project's dependencies, build-chain and deployment to [PyPI](https://pypi.org/) is managed with [Python Poetry](https://python-poetry.org/).

- Main project information is manged in file `pyproject.toml`
- Dependencies to the production are added by `poetry add <pypi-package-name>` or removed by `poetry remove <pypi-package-name>`
- Dependencies only needed for development are added by `poetry add --dev <pypi-package-name>` or removed by `poetry remove --dev <pypi-package-name>`

!!! note ""
    In case of problems, it usually helps to manually delete the automatically generated `poetry.lock`-file and to run `poetry install` to reinstall all dependencies with recalculation of dependency tree.

### Version Management

Versioning is managed also by [Python Poetry](https://python-poetry.org/) using [SemVer](https://semver.org/lang/de/):

- Major version update: `poetry version major` (for large releases with completely new feature sets and/or breakting API)
- Minor version update: `poetry version minor` (for minor feature additions and/or non-breaking api changes)
- Patch version update: `poetry version patch` (for bugfixes, minor documentation updates)

Though versioning is managed with [Python Poetry](https://python-poetry.org/), the version definition needs manual update in the following steps and locations:

1. Major/Minor/Patch version update using one of the above `poetry version` commands
2. Manual update of `src/__init__.py:__version__`
3. Manual update of command for rebuilding the documentation (only for preview locally, production versioning is handled in Github actions). See section _Documentation_ below.

### Setup

In VS Code with the project's folder opened in a container, initiate the Poetry project and create a virtual environment. Make sure you are in the `application-server` directory. In there run the Poetry init command that will bootstrap all configuration files.

```bash
poetry init
```

Answer the questions of the project creation wizard to create an initial `pyproject.toml` file:

```text
Package name [application-server]: <ENTER>
Version [0.1.0]:  0.0.0 <ENTER>
Description []: Configuration options with multiple config-files and command-line made easy when creating applications with Python Click. <ENTER>
Author [John Doe <john.doe@internet.com>: <ENTER>
License []: MIT <ENTER>
Compatible Python versions [^3.9]: <ENTER>
Would you like to define your main dependencies interactively? (yes/no) [yes] no <ENTER>
Would you like to define your development dependencies interactively? (yes/no) [yes] no <ENTER>
Do you confirm generation? (yes/no) [yes] <ENTER>
```

Create and change into a virtual environment:

```bash
poetry shell
```

Then add from command-line all direct production dependencies.

- [sqlmodel](https://sqlmodel.tiangolo.com/) SQLModel, SQL databases in Python, designed for simplicity, compatibility, and robustness.
- [fastapi](https://fastapi.tiangolo.com/) FastAPI framework, high performance, easy to learn, fast to code, ready for production
- [uviocorn](https://www.uvicorn.org/) Uvicorn is an ASGI web server implementation for Python.
- [click](https://click.palletsprojects.com/en/8.0.x/) Command Line Interface Creation Kit

```bash
poetry add sqlmodel fastapi "uvicorn[standard]" click 
```

Add all the development dependencies needed for testing, documentation and code review.

- [poethepoet](https://github.com/nat-n/poethepoet) A task runner that works well with poetry
- [pylint](https://www.pylint.org/) Python linter
- [black](https://github.com/psf/black) The uncompromising Python code formatter
- [mypy](http://www.mypy-lang.org/) static type checker for Python
- [pytest](https://docs.pytest.org/) (Unit) Test Framework
- [pytest-cov](https://github.com/pytest-dev/pytest-cov) Coverage plugin for pytest.
- [pytest-html](https://github.com/pytest-dev/pytest-html) Plugin for generating HTML reports for pytest results
- [hypothesis](https://hypothesis.works/) Fuzzy-testing for pytest
- [mkdocs](https://www.mkdocs.org/) Project documentation with Markdown
- [mkdocs-material](https://squidfunk.github.io/mkdocs-material/) Material design for mkdocs
- [markdown-include](https://github.com/cmacmackin/markdown-include/) Provides syntax for Python-Markdown which allows for the inclusion of the contents of other Markdown documents
- [mkdocs-exclude](https://github.com/apenwarr/mkdocs-exclude) A mkdocs plugin that lets you exclude files or trees from your output
- [mkdocstrings](https://mkdocstrings.github.io/) Automatic documentation from sources, for MkDocs
- [mkdocs-gen-files](https://github.com/oprypin/mkdocs-gen-files) MkDocs plugin to programmatically generate documentation pages during the build
- [mkdocs-pdf-export-plugin](https://github.com/zhaoterryy/mkdocs-pdf-export-plugin/) An MkDocs plugin to export content pages as PDF files
- [mkdocs-mermaid2-plugin](https://github.com/fralau/mkdocs-mermaid2-plugin) A Mermaid graphs plugin for mkdocs
- [mkdocs-coverage](https://github.com/pawamoy/mkdocs-coverage) MkDocs plugin to integrate your coverage HTML report into your site
- [asciinema](https://asciinema.org/) recording terminal sessions
- [mike](https://github.com/jimporter/mike) Manage multiple versions of your MkDocs-powered documentation via Git

```bash
poetry add --dev poethepoet pylint black mypy pytest pytest-cov pytest-html hypothesis mkdocs mkdocs-material markdown-include mkdocs-exclude mkdocstrings mkdocs-gen-files mkdocs-pdf-export-plugin mkdocs-mermaid2-plugin mkdocs-coverage asciinema mike
```

In the post-build commands for the VSCode devcontainer, we ran `poetry config virtualenvs.in-project true`. See [Poetry documentation](https://python-poetry.org/docs/configuration/#virtualenvsin-project). This instructs Poetry to keep the dependencies on the host-system, in the virtualenv managed by Poetry inside the project's directory
Alternatively, you could configure poetry to store the virtual environment somewhere else in the container than the host-directory with the source code, mapped into the container. By that, you encapsulate
the dependencies, avoiding to clutter the host system with large directory trees. However, this requires re-installing all
dependencies with `poetry init` every time you rebuild the container. the disadvantage of this approach is, that re-installing the dependencies often may take too much time.

### Configuration

To configure all development dependencies, add to the `pyproject.toml` file the following sections.

Configuring _pytest_ output formatting and register plugins (_doctest_-plugin to test code in Python docstrings
and _coverage_ plugin to measure test-coverage).

```toml
[tool.pytest.ini_options]
log_cli = true
log_cli_level = "DEBUG"
log_cli_format = "%(asctime)s [%(levelname)8s] %(message)s (%(filename)s:%(lineno)s)"
log_cli_date_format = "%Y-%m-%d %H:%M:%S"
addopts = "--doctest-modules"

[tool.pytest]
addopts = "--cov=$(pwd) --cov-report html"
```

Configuring _coverage_ plugin to include the source-code directory only (and not eg the test-directory or
and existing virtual-environment).

```toml
[tool.coverage.paths]
source = [ "pyconfme" ]

[tool.coverage.run]
omit = [ "tests/*", ".venv/*" ]
```

Configuring _pylint_ maximum line-length.

```toml
[tool.pylint]
max-line-length = 88
```

Configuring _black_ code formatter to same line-length as _pylint_ and to some common-sense include/exclude rules.

```toml
[tool.black]
experimental-string-processing = true
line-length = 88
target-version = ['py39']
include = '\.pyi?$'
exclude = '''

(
  /(
      \.eggs         # exclude a few common directories in the
    | \.git          # root of the project
    | \.hg
    | \.mypy_cache
    | \.tox
    | \.venv
    | _build
    | buck-out
    | build
    | dist
  )/
  | foo.py           # also separately exclude a file named foo.py in
                     # the root of the project
)
'''
```

Configure _poethepoet_ task runner extension with some convenience commands.

- `poe t` for running tests
- `poe covtest` for running tests including coverage measurement
- `poe covreport` to get html-coverage report from latest coverage measurement
- `poe ct` to run both sequentially, tests including coverage measurement and coverage report creation
- `poe db` to (re-)build the documentation using the `_VERSION` variable to determine documentation version
- `poe d` serve documentation locally with _mike_'s test-server. Go to [http://localhost:8000](http://localhost:8000) in your local browser

```toml
[tool.poe.env]
_VERSION = "v0.0.0"

[tool.poe.tasks]
t = "pytest"
covtest = "coverage run -m pytest"
covreport = "coverage html"
ct = ["covtest", "covreport"]
db = [
        {cmd = "mike deploy $_VERSION"}, 
        {cmd = "mike set-default $_VERSION"}, 
        {cmd = "mike alias $_VERSION latest"}
    ]
d = "mike serve"
clean = """
rm -rf .coverage
       html_cov
       .mypy_cache
       .pytest_cache
       .hypothesis
       dist
       site
       ./**/__pycache__
"""
```













## Documentation

### General

Documentation is build using [mkdocs](https://www.mkdocs.org/) static page generator with several plugins which allow versioning, integration of docstring comments and deploying to [Github pages](https://docs.github.com/en/github/working-with-github-pages/getting-started-with-github-pages). The advantages of this approach are greater flexibility in page setup and design, integration of docstring comments and examples and simple local preview.

The main plugins are:

- For design, search and navigation: [mkdocs-material](https://squidfunk.github.io/mkdocs-material/getting-started/)
- For integration of docstring comments: [mkdoc-strings](https://github.com/mkdocstrings/mkdocstrings)
- For versioning: [mike](https://github.com/jimporter/mike)

### Setup

The documentation creation with _mkdocs_ is managed through the config file `mkdocs.yml`, which contains general site-parameters
(eg. title, theme), site structure and plugin-configuration.

Initial `mkdocs.yml` content:

```yaml
site_name: cloudcell application-server
site_description: Application server for scalable, K8s-based spreadsheets and simulations.
strict: true
site_url: https://bnaard.github.io/cloudcell-application-server

theme:
  name: 'material'
  custom_dir: 'docs/theme'
  palette:
    primary: blue
    accent: blue
#  logo: 'logo-white.svg'
#  favicon: 'favicon.png'

repo_name: bnaard/oyconfme
repo_url: https://github.com/bnaard/pyconfme

nav:
- Overview: index.md


markdown_extensions:
- markdown_include.include:
    base_path: docs
- toc:
    permalink: 🔗
- pymdownx.highlight
- pymdownx.extra
- admonition
- pymdownx.details
- pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_div_format
- pymdownx.emoji
- pymdownx.magiclink
- pymdownx.snippets:
    check_paths: true
- pymdownx.tabbed
- pymdownx.tasklist


plugins:
- search
# - pdf-export
- autorefs
- coverage:
    page_name: coverage  # default
    html_report_dir: htmlcov
- mkdocstrings:
    handlers:
        python:
          rendering:
            show_root_heading: no 
            show_category_heading: no
            show_if_no_docstring: yes     
- exclude:
    glob:
    - _build/*
    - build/*
    - examples/*
    - requirements.txt

extra:
  version:
    provider: mike

extra_css:
  - stylesheets/asciinema-player.css
extra_javascript:
  - javascripts/asciinema-player.js
  - https://unpkg.com/mermaid/dist/mermaid.min.js
```

Manually add the JavaScript and CSS static assets for [asciinema-player](https://github.com/asciinema/asciinema-player) as
it is not distrubuted on a CDN at the time of writing this.

- Download `asciinema-player.min.js` from [Asciinema releases page](https://github.com/asciinema/asciinema-player/releases) and store in `.\docs\javascripts`
- Download `asciinema-player.css` from [Asciinema releases page](https://github.com/asciinema/asciinema-player/releases) and
store in `.\docs\stylesheets`

!!! note ""
    This dependency has to be manually updated as it is not managed through _poetry_.

### Github Hosting

We use Github for serving the static build of the documentation websites. For that, GitHub _Pages_ have to be enabled and
our configuration has to ensure that Github does not try to use its standard-renderer [jekyll](https://jekyllrb.com/) to build
our documentation. Instead, we instruct Github to serve pages _as is_ without rendering.

To do so, we first enable Guthub pages, then we disable the standard renderer _jekyll_.

Create a dedicated branch for the built documentation:

- in Github webinterface create a new branch `gh-pages` from `main` branch

To enable Github pages:

- go to Github repository web-interface
- go to _Settings_ tab
- select _Pages_ in the left box
- select as _Source_ the branch _gh-pages_ and select `\root` as folder
- click _Save_ and ignore for now that Github reports that the documentation build fails

Instruct Github to not use standard renderer _jekyll_:

- place an empty file named `.nojekyll` in the root directory of the built documentation

All productive documentation is hosted on `gh-pages`-branch of this repository. This is automatically managed and overwritten by the _mkdoc_-tools mentioned above. So, do not edit manually the `gh-pages`-branch as all your changes will be overwritten and lost on next documentation auto-build+deploy.

## Github Actions

_build_ (here: a pipeline of linting and running all tests) and _docs_ (here: document creation with _mkdocs_) are implemented as Github actions.

Both actions are setup in Github webinterface.

Initial content `build.yml`

```yaml
# This workflow will install Python dependencies, run tests and lint with a variety of Python versions
# For more information see: https://help.github.com/actions/language-and-framework-guides/using-python-with-github-actions

name: Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:

    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.7, 3.8, 3.9]

    steps:
    - uses: actions/checkout@v2
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v2
      with:
        python-version: ${{ matrix.python-version }}
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        python -m pip install poetry
        poetry config virtualenvs.in-project true
        poetry install
        # if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
    - name: Lint with pylint
      run: |
        python lint.py --path ./pyconfme --threshold 2
      continue-on-error: true
    - name: Test with pytest
      run: |
        ./.venv/bin/pytest --doctest-modules --html=test-results-${{ matrix.python-version }}.html --cov-report=html --cov=./pyconfme/ .
      continue-on-error: true
    - name: Upload pytest test results
      uses: actions/upload-artifact@v2
      with:
        path: | 
          test-results-${{ matrix.python-version }}.html
          assets/*
    - name: Upload test coverage results
      uses: actions/upload-artifact@v2
      with:
        path: ./htmlcov  
      # Use always() to always run this step to publish test results when there are test failures
      if: ${{ always() }}
```

Initial content `docs.yml`

```yaml
name: Docs

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-18.04
    strategy:
      matrix:
        python-version: [ '3.9' ]

    steps:
    - uses: actions/checkout@v2
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v2
      with:
        python-version: ${{ matrix.python-version }}
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        python -m pip install poetry
        poetry config virtualenvs.in-project true
        poetry install

    - uses: actions-ecosystem/action-get-latest-tag@v1
      id: get-latest-tag
      with:
        semver_only: true

    - run: |
        export PATH="$PATH:$PWD/.venv/bin"
        git config --global user.name "$(git --no-pager log --format=format:'%an' -n 1)"
        git config --global user.email "$(git --no-pager log --format=format:'%ae' -n 1)"
        mike deploy --update-aliases ${{ steps.get-latest-tag.outputs.tag }} latest
        mike set-default latest

    - name: Deploy
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./site
```

The Github action described in `.github/workflows/docs.yml` is based on [GitHub Actions for GitHub Pages](https://github.com/peaceiris/actions-gh-pages), which builds and deploys _mkdoc_ page structures and takes care that Github is serving those _as is_ instead of using Jekyll.

In the Github actions, the latest version is retrieved using [get-latest-tag](https://github.com/marketplace/actions/actions-ecosystem-action-get-latest-tag) to build the latest documentation.

While documentation updates including documentation versions on Github are automatically done based on latest tag information (see `.github/workflows/Docs.yml`), you need to run the following to locally build and serve the versioned documentation for preview on [https://localhost:8000](https://localhost:8000):

```bash
mike deploy --update-aliases 0.1.0 latest   # replace 0.1.0 manually with the current version from pyconfme/__init__.py
mike set-default latest
mike serve
```

!!! note ""
    You have to run both commands to get a proper redirect to the latest documentation on [https://localhost:8000](https://localhost:8000). Refer to [mkdocs-material documentation](https://squidfunk.github.io/mkdocs-material/setup/setting-up-versioning/) and to [mike documentation](https://github.com/jimporter/mike#usage) for details.

!!! note ""
    Instead of running `mike deploy` manually, you can use the _poethepoet_ actions described earlier.

Create a test-build of the documentation by changing into the virtual-environment and then using the _poe_ build task for the documentation.

```bash
poetry shell
poe db
```





Using Helm Chart

    Update Helm repositories and download dependencies: helm dependency update ./helm/voting-app
    Deploy the Helm Chart: helm template voting-app ./helm/voting-app --namespace=voting-app-stack | kubectl apply -f -
    Get your cluster IP using: minikube ip
    Enable ingress access:
        On Linux: Edit your hosts file located at /etc/hosts by adding <minikube ip> result.votingapp.com vote.votingapp.com to the end of it, of course replace <minikube ip> by the real cluster ip.
        On Windows: Edit your hosts file located at c:\Windows\System32\Drivers\etc\hosts by adding 127.0.0.1 result.votingapp.com vote.votingapp.com to the end of it. After that, start a Minikube tunnel: minikube tunnel

The result app should be now accessible through result.votingapp.com and the vote one to vote.votingapp.com To stop and destroy all k8s deployed ressources run: helm template voting-app ./helm/voting-app --namespace=voting-app-stack | kubectl delete -f - and stop minikube using minikube stop




Run with Kubernetes
Minikube

Before deploying the app, you must install Minikube and start a cluster:

    Install Minikube
    Start a Minikube cluster: minikube start
    Check that Minikube is fully up (minikube status) and kubectl successfully linked (kubectl get pods -A)
    Enable Nginx Ingress Controller addon: minikube addons enable ingress

Using k8s templates

    Deploy all k8s ressources: kubectl apply -f k8s-specifications --namespace=voting-app-stack
    Get your cluster IP using: minikube ip
    Enable ingress access:
        On Linux: Edit your hosts file located at /etc/hosts by adding <minikube ip> result.votingapp.com vote.votingapp.com to the end of it, of course replace <minikube ip> by the real cluster ip.
        On Windows: Edit your hosts file located at c:\Windows\System32\Drivers\etc\hosts by adding 127.0.0.1 result.votingapp.com vote.votingapp.com to the end of it. After that, start a Minikube tunnel: minikube tunnel

The result app should be now accessible through result.votingapp.com and the vote one to vote.votingapp.com To stop and destroy all k8s deployed ressources run: kubectl delete -f k8s-specifications --namespace=voting-app-stack and stop minikube using minikube stop

Summary
