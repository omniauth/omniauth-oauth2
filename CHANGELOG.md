# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Changes before 1.8.0 were originally published only on [GitHub Releases](https://github.com/omniauth/omniauth-oauth2/releases). The entries below for those versions are taken from there; releases before 1.6.0 have no recorded notes.

## [Unreleased]

### Added

- RBS type signatures for the strategy, in `sig/`, checked with Steep.

## [1.9.0] - 2025-12-11

### Fixed

- Rescue OAuth2 timeouts. ([#169])

### Security

- Prevent timing attacks on the CSRF state check. ([#174])

## [1.8.0] - 2022-06-18

### Changed

- Relax the allowed versions of the oauth2 gem. ([#146])
- Require omniauth `~> 2.0`. ([#152])

## [1.7.3] - 2022-06-19

### Changed

- Relax the oauth2 gem requirement, without the stricter omniauth requirement that 1.8.0 introduces.

## [1.7.2] - 2021-11-02

### Security

- Patch a vulnerability reported to GitLab, where a malicious actor could craft a callback URL that displayed an arbitrary message to users without checking that the callback state matched omniauth's session state. Thanks to the folks at GitLab for upstreaming this fix.

## [1.7.1] - 2021-01-11

### Changed

- Relax the OmniAuth requirement to allow [OmniAuth 2.0.0](https://github.com/omniauth/omniauth/releases/tag/v2.0.0).

## [1.7.0] - 2020-08-11

### Added

- A `pkce` strategy option to use [PKCE](https://tools.ietf.org/html/rfc7636). Enable it with `option :pkce, true`. It uses the recommended `S256` code challenge method by default; to use another, set `option :pkce_options, {code_challenge: proc { |verifier| verifier }, code_challenge_method: "basic"}`. The `code_challenge` must respond to `call`.

## [1.6.0] - 2018-12-14

### Changed

- Require OmniAuth 1.9.0 or later for its additional security updates.
- Update the supported Ruby versions.

### Security

- CVE-2015-1820: Fix the rest-client vulnerability.

## [1.5.0] - 2017-12-13

## [1.4.0] - 2015-10-21

## [1.3.1] - 2015-06-22

## [1.3.0] - 2015-04-22

## [1.2.0] - 2014-07-09

## [1.1.2] - 2014-01-16

## [1.1.1] - 2012-09-18

## [1.1.0] - 2012-07-06

## [1.0.3] - 2012-07-05

## [1.0.2] - 2012-04-27

## [1.0.1] - 2012-04-13

## [1.0.0] - 2011-11-02

## [1.0.0.rc2] - 2011-10-28

## [1.0.0.rc1] - 2011-10-28

## [1.0.0.beta1] - 2011-10-19

## [1.0.0.pr2] - 2011-10-13

## [1.0.0.pr1] - 2011-10-13

[Unreleased]: https://github.com/omniauth/omniauth-oauth2/compare/v1.9.0...HEAD
[1.9.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.7.2...v1.8.0
[1.7.3]: https://github.com/omniauth/omniauth-oauth2/compare/v1.7.2...v1.7.3
[1.7.2]: https://github.com/omniauth/omniauth-oauth2/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/omniauth/omniauth-oauth2/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/omniauth/omniauth-oauth2/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/omniauth/omniauth-oauth2/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/omniauth/omniauth-oauth2/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.0.rc2...v1.0.0
[1.0.0.rc2]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.0.rc1...v1.0.0.rc2
[1.0.0.rc1]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.0.beta1...v1.0.0.rc1
[1.0.0.beta1]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.0.pr2...v1.0.0.beta1
[1.0.0.pr2]: https://github.com/omniauth/omniauth-oauth2/compare/v1.0.0.pr1...v1.0.0.pr2
[1.0.0.pr1]: https://github.com/omniauth/omniauth-oauth2/releases/tag/v1.0.0.pr1

[#146]: https://github.com/omniauth/omniauth-oauth2/pull/146
[#152]: https://github.com/omniauth/omniauth-oauth2/pull/152
[#169]: https://github.com/omniauth/omniauth-oauth2/pull/169
[#174]: https://github.com/omniauth/omniauth-oauth2/pull/174
