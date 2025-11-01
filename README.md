<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# Fuzzy Backgrounds

Fuzzy backgrounds allows you to use fuzzy, dynamic (fluid) backgrounds in your Flutter applications.

[![pub package](https://img.shields.io/pub/v/fuzzy_backgrounds.svg)](https://pub.dev/packages/fuzzy_backgrounds)
[![GitHub issues](https://img.shields.io/github/issues/RayLabz/fuzzy_backgrounds.svg)]()
![GitHub stars](https://img.shields.io/github/stars/RayLabz/fuzzy_backgrounds.svg?style=social&label=Star)
![GitHub license](https://img.shields.io/github/license/RayLabz/fuzzy_backgrounds.svg)

---

## Features

You can choose from several types of backgrounds.

<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/gradient-background.gif?raw=true" alt="drawing" width="200"/>
<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/fuzzy-circles.gif?raw=true" alt="drawing" width="200"/> 
<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/bloomy-orbs.gif?raw=true" alt="drawing" width="200"/>
<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/ribbon.gif?raw=true" alt="drawing" width="200"/>
<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/aurora.gif?raw=true" alt="drawing" width="200"/>
<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/rays-background.gif?raw=true" alt="drawing" width="200"/>
<img src="https://github.com/RayLabz/fuzzy_backgrounds/blob/main/media/flow-fields.gif?raw=true" alt="drawing" width="200"/>

## Installing

To get started, install `fuzzy_backgrounds`:

```shell
flutter pub add fuzzy_backgrounds
```

## Usage

You can use different types of backgrounds in your code by including the widgets
and wrapping your content as their `child` property:

```dart
FuzzyCirclesBackground(
    child: const Text(
      'Circles Background',
      style: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
),
```

## Customization

Different backgrounds offer various customization options including animation speed, colors, 
particle numbers and more.

For more information refer to the [documentation](https://raylabz.github.io/fuzzy_backgrounds/api).
