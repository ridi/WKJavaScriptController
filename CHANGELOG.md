# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

* None.

## [2.0.2 (2020-02-06)]

### Added

* Support Swift Package Manager.

## [2.0.1 (2019-03-06)]

### Changed

* Change `JSValueType` description to string value.

## [2.0.0 (2019-02-28)]

### Added

* Support native return to JavaScript as [Promise](https://developer.mozilla.org/ko/docs/Web/JavaScript/Reference/Global_Objects/Promise).
* Add `logEnabled` property. (default: `true`)
* Add `callbackTimeout` property. (default: `10`)

### Changed

* Rename `shouldSafeMethodCall` to `ignoreMethodCallWhenReceivedNull`.
* Rename `shouldConvertJSONString` to `convertsToDictionaryWhenReceivedJsonString`.

### Fixed

* Fix an issue where string composed of numbers were cast to `JSInt` by parsing top-level objects as `JSONSerialization` with `allowFragments` read option.

## [1.2.0 (2019-02-26)]

### Changed

* Migrate to Swift 4.2.

## [1.1.9 (2018-07-31)]

### Fixed

* Fix an issue where compile error with Xcode 9 in Swift 4 mode.

## [1.1.8 (2017-11-29)]

* None.

## [1.1.7 (2017-09-26)]

### Fixed

* Fix build error with Xcode 9.

## [1.1.6 (2017-07-05)]

### Fixed

* Fix build error with Xcode 9.

## [1.1.5 (2017-02-08)]

### Changed

* Change method invocation notification send order.

## [1.1.4 (2017-02-05)]

### Added

* Add `shouldConvertJSONString` option.

### Fixed

* Fix to read methods of higher protocols.

## [1.1.3 (2017-01-26)]

### Fixed

* Fix JSON parse error.

## [1.1.2 (2017-01-26)]

### Fixed

* Fix cast arguments.

## [1.1.1 (2017-01-26)]

### Added

* Add method invocation notification.
* Add `shouldSafeMethodCall` property.

## [1.1.0 (2017-01-18)]

### Changed

* Migrate to Swift 3.

## [1.0.2 (2017-01-18)]

* None.

## [1.0.1 (2017-01-18)]

### Fixed

* Fix an issue where swift value type was parsed incorrectly.

## [1.0.0 (2017-01-17)]

* First release.

[Unreleased]: https://github.com/ridi/WKJavaScriptController/compare/2.0.2...HEAD
[2.0.2 (2020-02-06)]: https://github.com/ridi/WKJavaScriptController/compare/2.0.1...2.0.2
[2.0.1 (2019-03-06)]: https://github.com/ridi/WKJavaScriptController/compare/2.0.0...2.0.1
[2.0.0 (2019-02-28)]: https://github.com/ridi/WKJavaScriptController/compare/1.2.0...2.0.0
[1.2.0 (2019-02-26)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.9...1.2.0
[1.1.9 (2018-07-31)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.8...1.1.9
[1.1.8 (2017-11-29)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.7...1.1.8
[1.1.7 (2017-09-26)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.6...1.1.7
[1.1.6 (2017-07-05)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.5...1.1.6
[1.1.5 (2017-02-08)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.4...1.1.5
[1.1.4 (2017-02-05)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.3...1.1.4
[1.1.3 (2017-01-26)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.2...1.1.3
[1.1.2 (2017-01-26)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.1...1.1.2
[1.1.1 (2017-01-26)]: https://github.com/ridi/WKJavaScriptController/compare/1.1.0...1.1.1
[1.1.0 (2017-01-18)]: https://github.com/ridi/WKJavaScriptController/compare/1.0.2...1.1.0
[1.0.2 (2017-01-18)]: https://github.com/ridi/WKJavaScriptController/compare/1.0.1...1.0.2
[1.0.1 (2017-01-18)]: https://github.com/ridi/WKJavaScriptController/compare/1.0.0...1.0.1
[1.0.0 (2017-01-17)]: https://github.com/ridi/WKJavaScriptController/compare/8065709...1.0.0
