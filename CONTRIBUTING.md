# Contributing Guidelines

Pull requests, bug reports, and all other forms of contribution are welcomed and highly encouraged!

### Contents

- [Contributing Guidelines](#contributing-guidelines)
    - [Contents](#contents)
  - [Code of Conduct](#code-of-conduct)
  - [Asking Questions](#asking-questions)
  - [Opening an Issue](#opening-an-issue)
    - [Reporting Security Issues](#reporting-security-issues)
    - [Bug Reports and Other Issues](#bug-reports-and-other-issues)
  - [Submitting Pull Requests](#submitting-pull-requests)
  - [Writing Commit Messages](#writing-commit-messages)
  - [Code Review](#code-review)
  - [Coding Style](#coding-style)
  - [Development Setup](#development-setup)

> **This guide serves to set clear expectations for everyone involved with the project so that we can improve it together while also creating a welcoming space for everyone to participate. Following these guidelines will help ensure a positive experience for contributors and maintainers.**

## Code of Conduct

Please review our [Code of Conduct](CODE_OF_CONDUCT.md). It is in effect at all times. We expect all contributors to act professionally and respectfully. Harassment or abusive behavior will not be tolerated.

## Asking Questions

In short, GitHub issues are not the appropriate place to debug your specific project, but should be reserved for filing bugs and feature requests. For general questions about LearnWay, reach out at **support@learnway.xyz**.

## Opening an Issue

Before [creating an issue](https://help.github.com/en/github/managing-your-work-on-github/creating-an-issue), check if you are using the latest version of the project. If you are not up-to-date, see if updating fixes your issue first.

### Reporting Security Issues

Review our [Security Policy](SECURITY.md). **Do not** file a public issue for security vulnerabilities.

### Bug Reports and Other Issues

A great way to contribute to the project is to send a detailed issue when you encounter a problem. We always appreciate a well-written, thorough bug report.

- **Review the [README](README.md)** before opening a new issue.
- **Do not open a duplicate issue!** Search through existing issues to see if your issue has previously been reported. If your issue exists, comment with any additional information you have. You may simply note "I have this problem too", which helps prioritize the most common problems and requests.
- **Prefer using [reactions](https://github.blog/2016-03-10-add-reactions-to-pull-requests-issues-and-comments/)**, not comments, if you simply want to "+1" an existing issue.
- **Fully complete the provided issue template.** The bug report template requests all the information we need to quickly and efficiently address your issue. Be clear, concise, and descriptive. Provide as much information as you can, including steps to reproduce, contract names, transaction hashes, and network details.
- **Use [GitHub-flavored Markdown](https://help.github.com/en/github/writing-on-github/basic-writing-and-formatting-syntax).** Especially put code blocks and console outputs in backticks (```). This improves readability.

## Submitting Pull Requests

We **love** pull requests! Before [forking the repo](https://help.github.com/en/github/getting-started-with-github/fork-a-repo) and [creating a pull request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/proposing-changes-to-your-work-with-pull-requests) for non-trivial changes, it is usually best to first open an issue to discuss the changes, or discuss your intended approach for solving the problem in the comments for an existing issue.

_Note: All contributions will be licensed under the project's license._

- **Smaller is better.** Submit **one** pull request per bug fix or feature. A pull request should contain isolated changes pertaining to a single bug fix or feature implementation. **Do not** refactor or reformat code that is unrelated to your change. It is better to **submit many small pull requests** rather than a single large one. Enormous pull requests will take enormous amounts of time to review, or may be rejected altogether.
- **Coordinate bigger changes.** For large and non-trivial changes, open an issue to discuss a strategy with the maintainers. Otherwise, you risk doing a lot of work for nothing!
- **Prioritize understanding over cleverness.** Write code clearly and concisely. Remember that source code usually gets written once and read often. Ensure the code is clear to the reader.
- **Follow existing coding style and conventions.** Keep your code consistent with the style, formatting, and conventions in the rest of the code base.
- **Include test coverage.** Add tests when possible. Follow existing patterns for implementing tests using Foundry.
- **Use the `dev` branch.** Branch from and [submit your pull request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork) to the `dev` branch. Do not target `main` directly.
- **[Resolve any merge conflicts](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/resolving-a-merge-conflict-on-github)** that occur.
- **Promptly address any CI failures**. If your pull request fails to build or pass tests, please push another commit to fix it.

## Writing Commit Messages

Please [write a great commit message](https://chris.beams.io/posts/git-commit/).

1. Separate subject from body with a blank line
1. Limit the subject line to 50 characters
1. Capitalize the subject line
1. Do not end the subject line with a period
1. Use the imperative mood in the subject line (example: "Fix reentrancy in badge mint")
1. Wrap the body at about 72 characters
1. Use the body to explain **why**, _not what and how_ (the code shows that!)

## Code Review

- **Review the code, not the author.** Look for and suggest improvements without disparaging or insulting the author. Provide actionable feedback and explain your reasoning.
- **You are not your code.** When your code is critiqued, questioned, or constructively criticized, remember that you are not your code. Do not take code review personally.
- **Always do your best.** No one writes bugs on purpose. Do your best, and learn from your mistakes.
- Kindly note any violations to the guidelines specified in this document.

## Coding Style

Consistency is the most important. Follow the existing style, formatting, and naming conventions of the file you are modifying and of the overall project. Failure to do so will result in a prolonged review process that has to focus on updating the superficial aspects of your code, rather than improving its functionality and performance.

For example, if all private properties are prefixed with an underscore \_, then new ones you add should be prefixed in the same way. Or, if methods are named using camelcase, like thisIsMyNewMethod, then do not diverge from that by writing this_is_my_new_method. You get the idea. If in doubt, please ask or search the codebase for something similar.

## Development Setup

**Requirements:** [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
# Clone the repo
git clone https://github.com/learnwayxyz/learnway_v2_contracts.git
cd learnway_v2_contracts

# Install dependencies
forge install

# Build
forge build

# Run tests
forge test
```
