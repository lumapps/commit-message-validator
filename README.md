# Commit message validator

<!-- PROJECT SHIELDS -->

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<!-- markdownlint-disable no-inline-html -->
<br />
<p align="center">
  <a href="https://github.com/lumapps/commit-message-validator">
    <img src="images/stamp.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">Commit message validator</h3>

  <p align="center">
    Enforce angular commit message convention with minimal dependancy only
    git and bash.
    <br />
    <a href="https://github.com/lumapps/commit-message-validator">
      <strong>Explore the docs »
    </strong></a>
    <br />
    <br />
    <a href="https://github.com/lumapps/commit-message-validator/issues">
      Report Bug
    </a>
    ·
    <a href="https://github.com/lumapps/commit-message-validator/issues">
      Request Feature
    </a>
  </p>
</p>
<!-- markdownlint-enable no-inline-html -->

<!-- TABLE OF CONTENTS -->

## Table of Contents

- [About the Project](#about-the-project)
  - [Built With](#built-with)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [Acknowledgements](#acknowledgements)

<!-- ABOUT THE PROJECT -->

## About The Project

The provided script enforce Angular commit message convention, with an
opinionated reduction of allowed types. Moreover, it enforces reference to a
project management tools named JIRA.

### Commit Message Format

Each commit message consists of a **header**, a **body** and a **footer**.
The header has a special format that includes a **type**, a **scope** andi
a **subject**:

```Markdown
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

- The first line of the commit message (the "Subject") cannot be longer than 70
  characters.
- Any other line of the commit message cannot be longer 100 characters!
- The body and footer are optional, but depends on the type, information can be
   mandatory.

This allows the message to be easier to read on github as well as in various
git tools.

### Type

Must be one of the following:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **lint**: Changes that do not affect the meaning of the code (white-space,
  formatting, missing semicolons, etc)
- **refactor**: A code change that neither fixes a bug or adds a feature
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to the build process or auxiliary tools and libraries such
  as distribution generation

### Scope

The scope could be anything specifying place of the commit change. For example
`notification', 'dropdown', etc.
The scope must be written in
[kebab-case](https://en.wikipedia.org/wiki/Letter_case#Special_case_styles).

### Subject

A brief but meaningfull description of the change.
Here are recommandations for writing your subject:

- use the imperative, present tense: "change" not "changed" nor "changes"
- don't capitalize first letter
- no "." (dot) at the end

### Body

The body should include the motivation for the change and contrast this
with previous behavior.
It is optional but highly recommended for any impacting changes.

### Footer

The footer should contain any information about **Breaking Changes** and is
also the place to reference JIRA ticket related to this commit.

The footer is optional but for **feat** and **fix** type the JIRA reference
is mandatory.

The breaking changes must be at the end of the commit with only "BROKEN:"
before the list of breaking changes. They must be each on a new line.

### Commit Example

```Markdown
feat(toto-service): provide toto for all

Before we had to do another thing. There was this and this problem.
Now, by using "toto", it's simpler and the problems are managed.

LUM-3462
BROKEN:
first thing broken
second thing broken
```

### Revert

The proper for revert based on Angular commit message convention should be:

```Markdown
revert: feat(toto-service): provide toto for all

This reverts commit <sha1>.
```

However, the default git behavior, that cannot be easily overiden is:

```Markdown
Revert "feat(toto-service): provide toto for all"

This reverts commit <sha1>.
```

Thus we won't enforce one or the other, we will only enfore:

- starting the commit title with revert (with a capitalized letter or not)
- having the sentence "This reverts commit \<sha1\>"

### Built With

- [bash](https://www.gnu.org/software/bash/)
- [bats](https://github.com/sstephenson/bats)

<!-- GETTING STARTED -->

## Getting started with command line

To get a local copy up and running follow these steps.

### Prerequisites

1. Install bash

   ```sh
   sudo apt install bash
   ```

2. Install bats for development testing

   ```sh
   sudo apt install bats
   ```

### Installation

1. Clone the commit-message-validator

   ```sh
   git clone https://github.com/lumapps/commit-message-validator.git
   ```

That's all, your ready to go !

<!-- USAGE EXAMPLES -->

## Usage

Check the commit message referenced by \<commit1\>:

```sh
./check.sh <commit1>
```

Check all the commits between 2 references:

```sh
./check.sh <commit1>..<commit2>
```

Behind the hood, the script use `git log` to list all the commit thus any
syntax allowed by git will be working.

You can also use the pre-push commit validator, simply copy, `pre-push`,
`validator.sh` and `check.sh` files
in `.git/hooks` directory of your repository.

### Command line Options

- if `COMMIT_VALIDATOR_NO_JIRA` environment variable is not empty,
  no validation is done on JIRA refs.
- if `COMMIT_VALIDATOR_ALLOW_TEMP` environment variable is not empty,
  no validation is done on `fixup!` and `squash!` commits.
- if `COMMIT_VALIDATOR_NO_REVERT_SHA1` environment variable is not empty,
  no validation is done revert commits.

### Commit template

You want to use the predefined commit template to keep the main information
under hand.

For that, you have to add the following lines in your repository's gitconfig
(located at `<project_root>/.gitconfig`).

```conf
[commit]
    template = /path/to/git-commit-template
```

## Getting started with github action

To enable the action simply create the
.github/workflows/commit-message-validator.yml file with the following content:

```yml
name: "Commit message validation on pull request"

on: pull_request

jobs:
  commit-message-validation:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Commit message validation
        uses: lumapps/commit-message-validator@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Github Action option

- if `no_jira` is not empty, no validation is done on JIRA refs.
- if `allow_temp` is not empty, no validation is done on `fixup!`
  and `squash!` commits.
- if `no_revert_sha1` is not empty, no validation is done on revert
  commits.
- `jira_in_header` jira reference can be put in the commit header.
- `header_length` allow to override the max length of the header line.
- `jira_types` takes a space separated list `"feat fix"` as a parameter to override the default types requiring a jira

## Add pre-commit plugin

If you are using [pre-commit](https://pre-commit.com/) in you repository,
you can add this to your configuration so commit messages are checked locally:

Into `.pre-commit-config.yaml`:

```yaml
default_stages: [commit]
repos:
  - repo: https://github.com/lumapps/commit-message-validator
    rev: master
    hooks:
      - id: commit-message-validator
        stages: [commit-msg]
        args: [--allow-temp]
```

`default_stages` tells which stage to install hooks that do not specify
a `stages` option.

Then run `pre-commit install --hook-type commit-msg` to install the
`commit-message-validator`

### Pre commit hook options

- if `no-jira` is set, no validation is done on JIRA refs.
- if `allow-temp` is set, no validation is done on `fixup!` and `squash!`
  commits.
- if `no-revert-sha1` is set, no validation is done on revert commits.
- if `--jira-in-header` jira reference can be put in the commit header.
- `--header-length` allow to override the max length of the header line.
- `--jira-types` takes a space separated list `"feat fix"` as a parameter to override the default types requiring a jira

<!-- ROADMAP -->

## Roadmap

See the [open issues](https://github.com/lumapps/commit-message-validator/issues)
for a list of proposed features (and known issues).

- [x] list all the commit, and run validation on each
- [x] enforce the overall commit message structure
- [x] enforce the overall commit header structure
- [x] enforce the overall commit header length
- [x] enforce the commit type
- [x] enforce the commit scope
- [x] enforce the commit subject
- [x] enforce the commit body length
- [x] enforce the JIRA reference
- [x] enforce the BROKEN part length
- [x] avoid trailing space
- [x] allow automated revert commit
- [x] allow fixup! and squash! commit with an option
- [x] allow to not check JIRA reference with an option
- [ ] enforce subject length (3 words at least)

<!-- CONTRIBUTING -->

## Contributing

Contributions are what make the open source community such an amazing place to be
learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Run the tests (`bats -j 100 validator.bats`)
5. Push to the Branch (`git push origin feature/AmazingFeature`)
6. Open a pull request

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE` for more information.

<!-- CONTACT -->

## Contact

Project Link: [https://github.com/lumapps/commit-message-validator](https://github.com/lumapps/commit-message-validator)

<!-- ACKNOWLEDGEMENTS -->

## Acknowledgements

<!-- markdownlint-disable no-inline-html -->
Icons made by <a href="https://www.flaticon.com/authors/freepik" title="Freepik">Freepik</a>
from <a href="https://www.flaticon.com/" title="Flaticon"> www.flaticon.com</a>
<!-- markdownlint-enable no-inline-html -->

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-shield]: https://img.shields.io/github/contributors/lumapps/commit-message-validator.svg?style=flat-square
[contributors-url]: https://github.com/lumapps/commit-message-validator/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/lumapps/commit-message-validator.svg?style=flat-square
[forks-url]: https://github.com/lumapps/commit-message-validator/network/members
[stars-shield]: https://img.shields.io/github/stars/lumapps/commit-message-validator.svg?style=flat-square
[stars-url]: https://github.com/lumapps/commit-message-validator/stargazers
[issues-shield]: https://img.shields.io/github/issues/lumapps/commit-message-validator.svg?style=flat-square
[issues-url]: https://github.com/lumapps/commit-message-validator/issues
[license-shield]: https://img.shields.io/github/license/lumapps/commit-message-validator.svg?style=flat-square
[license-url]: https://github.com/lumapps/commit-message-validator/blob/master/LICENSE
