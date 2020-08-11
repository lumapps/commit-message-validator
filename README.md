<!-- PROJECT SHIELDS -->

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/lumapps/commit-msg-validator">
    <img src="images/stamp.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">Commit message validator</h3>

  <p align="center">
    Enforce angular commit message convention with minimal dependancy only git and bash.
    <br />
    <a href="https://github.com/lumapps/commit-msg-validator"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/lumapps/commit-msg-validator/issues">Report Bug</a>
    ·
    <a href="https://github.com/lumapps/commit-msg-validator/issues">Request Feature</a>
  </p>
</p>

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

The provided script enforce Angular commit message convention, with an opinionated reduction of allowed types.
Moreover, it enforces reference to a project management tools named JIRA.

### Commit Message Format

Each commit message consists of a **header**, a **body** and a **footer**.
The header has a special format that includes a **type**, a **scope** and a **subject**:

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

- The first line of the commit message (the "Subject") cannot be longer than 70 characters.
- Any other line of the commit message cannot be longer 100 characters!

This allows the message to be easier to read on github as well as in various git tools.

### Type

Must be one of the following:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **lint**: Changes that do not affect the meaning of the code (white-space, formatting, missing semicolons, etc)
- **refactor**: A code change that neither fixes a bug or adds a feature
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to the build process or auxiliary tools and libraries such as distribution generation

### Scope

The scope could be anything specifying place of the commit change. For example `notification', 'dropdown', etc.
The scope must be written in [kebab-case](https://en.wikipedia.org/wiki/Letter_case#Special_case_styles).

### Subject

A brief but meaningfull description of the change.
Here are some recommandation for writing your subject:

- use the imperative, present tense: "change" not "changed" nor "changes"
- don't capitalize first letter
- no "." (dot) at the end

### Body

The body should include the motivation for the change and contrast this with previous behavior.

### Footer

The footer should contain any information about **Breaking Changes** and is also the place to
reference JIRA ticket related to this commit.
The breaking changes must be at the end of the commit with only "BROKEN:" before the list of breaking changes.
They must be each on a new line.

### Commit Example

```
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

```
revert: feat(toto-service): provide toto for all

This reverts commit <sha1>.
```

However, the default git behavior, that cannot be easily overiden is:

```
Revert "feat(toto-service): provide toto for all"

This reverts commit <sha1>.
```

Thus we won't enforce one or the other, we will only enfore:
* starting the commit title with revert (with a capitalized letter or not)
* having the sentence "This reverts commit <sha1>"

### Built With

- [bash](https://www.gnu.org/software/bash/)
- [bats](https://github.com/sstephenson/bats)

<!-- GETTING STARTED -->

## Getting Started

To get a local copy up and running follow these simple steps.

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

1. Clone the commit-msg-validator

```sh
git clone https://github.com/lumapps/commit-msg-validator.git
```

That's all, your ready to go !

<!-- USAGE EXAMPLES -->

## Usage

Check the commit message referenced by <commit1>:

```sh
./check.sh <commit1>
```

Check all the commits between 2 references:

```sh
./check.sh <commit1>..<commit2>
```

Behind the hood, the script use `git log` to list all the commit thus any syntax allowed by git will be working.

You can also use the pre-push commit validator, simply copy, `pre-push`, `validator.sh` and `check.sh` files
in `.git/hooks` directory of your repository.

<!-- ROADMAP -->

## Roadmap

See the [open issues](https://github.com/lumapps/commit-msg-validator/issues) for a list of proposed features (and known issues).

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
- [ ] allow fixup! and squash! commit with an option

<!-- CONTRIBUTING -->

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Run the tests (`bats -j 100 validator.bats`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE` for more information.

<!-- CONTACT -->

## Contact

Project Link: [https://github.com/lumapps/commit-msg-validator](https://github.com/lumapps/commit-msg-validator)

<!-- ACKNOWLEDGEMENTS -->

## Acknowledgements

Icons made by <a href="https://www.flaticon.com/authors/freepik" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon"> www.flaticon.com</a>

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
