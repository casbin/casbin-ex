# [1.3.0](https://github.com/casbin/casbin-ex/compare/v1.2.0...v1.3.0) (2025-10-30)


### Features

* improve README ([#35](https://github.com/casbin/casbin-ex/issues/35)) ([c478e2d](https://github.com/casbin/casbin-ex/commit/c478e2d06ccc8fcf972de81d04b2f187e1b6f392))

# [1.2.0](https://github.com/casbin/casbin-ex/compare/v1.1.0...v1.2.0) (2025-10-30)


### Features

* fix RBAC role inheritance with domains ([#29](https://github.com/casbin/casbin-ex/issues/29)) ([20c7b2b](https://github.com/casbin/casbin-ex/commit/20c7b2beb1ad809ffc65d2895d8b11dd9b291dca))

# [1.1.0](https://github.com/casbin/casbin-ex/compare/v1.0.0...v1.1.0) (2025-10-12)


### Features

* improve styles: Credo fixes, git pre-push hook ([#24](https://github.com/casbin/casbin-ex/issues/24)) ([e74ea15](https://github.com/casbin/casbin-ex/commit/e74ea15c9677d11cdb01c3b68e5dc72ebfded01e))

# 1.0.0 (2025-10-12)


### Bug Fixes

* add map support to request struct ([#8](https://github.com/casbin/casbin-ex/issues/8)) ([5b0e701](https://github.com/casbin/casbin-ex/commit/5b0e7012456f884fdb16bce2ddf12c1833093bb1))
* add_policy at enforcer server hasn't handled a case where new_enforce comes. ([#6](https://github.com/casbin/casbin-ex/issues/6)) ([a7478b8](https://github.com/casbin/casbin-ex/commit/a7478b83834c4019ed677eb8a7d2f50c3fca732b))
* enforcer_server ([#21](https://github.com/casbin/casbin-ex/issues/21)) ([85efaa4](https://github.com/casbin/casbin-ex/commit/85efaa43d38ce89065b150debbe51f9dbc7427b9))
* g3 matcher function + tests ([#13](https://github.com/casbin/casbin-ex/issues/13)) ([d26a73c](https://github.com/casbin/casbin-ex/commit/d26a73cde3801253c991d6a56762c4f664b2b707))


### Features

* add CI/CD automation with GitHub Actions and semantic-release ([#26](https://github.com/casbin/casbin-ex/issues/26)) ([f775b8f](https://github.com/casbin/casbin-ex/commit/f775b8f570065d0d9479b2a342240216a7efbea5))
* add EnforcerServer.reset_configuration/1 method ([#15](https://github.com/casbin/casbin-ex/issues/15)) ([0e530da](https://github.com/casbin/casbin-ex/commit/0e530daed509bc68240a8c366e18d7a5936fe0fe))
* added persist adapters and ability to alter policies and mappings ([#19](https://github.com/casbin/casbin-ex/issues/19)) ([d55e97a](https://github.com/casbin/casbin-ex/commit/d55e97a1bb6995db21fc56588ad1a28e0a9e2d73))
* keyMatch2 implementation ([#11](https://github.com/casbin/casbin-ex/issues/11)) ([c68edd2](https://github.com/casbin/casbin-ex/commit/c68edd2c8b60d1ce70a60dc0b0e8f6f9899b6f9d))
* RBAC domain model ([#10](https://github.com/casbin/casbin-ex/issues/10)) ([daafa79](https://github.com/casbin/casbin-ex/commit/daafa79a040520cdb5da9ff5ee70d800adc76bf6))
* upgrade required elixir version to 1.13 ([#17](https://github.com/casbin/casbin-ex/issues/17)) ([e828e3f](https://github.com/casbin/casbin-ex/commit/e828e3f7977bb1a41518543499da7bf1e5ab5ca2))


### BREAKING CHANGES

* Drop support for elixir < 1.13

* chore: mix format

* chore: Add .tool-versions
