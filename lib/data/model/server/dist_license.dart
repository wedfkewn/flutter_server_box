import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Puts the shipped marks' terms where the person running the app can read
/// them: Settings → About → License, which is Flutter's `showLicensePage` over
/// [LicenseRegistry].
///
/// Three of the four are under a Creative Commons licence — Alpine's mark is
/// simple enough that no copyright subsists in it — and every one of those
/// asks for credit "in any reasonable manner based on the medium, means, and
/// context". For an application that is the licence screen it already has.
/// `LicenseRegistry` collects each package's LICENSE file and nothing else, so
/// an asset is invisible to it until something registers one.
///
/// `assets/distro/README.md` carries the same notices and the reasoning; it
/// ships inside the bundle, because the whole directory is declared as an
/// asset, but nothing renders it — a notice nobody can reach is not one.
void registerDistMarkLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks([_package], _preamble);
    yield const LicenseEntryWithLineBreaks([_package], _debian);
    yield const LicenseEntryWithLineBreaks([_package], _gentoo);
    yield const LicenseEntryWithLineBreaks([_package], _nixos);
    yield const LicenseEntryWithLineBreaks([_package], _alpine);
    yield LicenseEntryWithLineBreaks(['Brand logos (assets/brands)'],
      await rootBundle.loadString('assets/brands/README.md'));
    for (final source in ['devicon', 'font-logos', 'simple-icons']) {
      yield LicenseEntryWithLineBreaks(['Brand logos ($source)'],
        await rootBundle.loadString('assets/brands/$source-LICENSE.txt'));
    }
  });
}

/// One heading for all of them, since they are one thing as far as a reader is
/// concerned: the small marks drawn beside a server's name.
const _package = 'Distribution marks (assets/distro)';

const _preamble = '''
Four original distribution logos live in assets/distro, with the individual
notices below. Additional original-color system and program logos live in
assets/brands, with their source manifest and upstream license texts.
Each logo identifies the installed system or program, without endorsement.
The original artwork colors and aspect ratio are preserved.
''';

const _debian = '''
The Debian Open Use Logo — (c) the Debian Project.
https://www.debian.org/logos/

Dual licensed under the GNU Lesser General Public License version 3 or later,
or the Creative Commons Attribution-ShareAlike 3.0 Unported License
(https://creativecommons.org/licenses/by-sa/3.0/). Used here under the latter.
Debian asks that the image link to https://www.debian.org/ where it is used on
a web page; this is an application, not a page, and the mark is not a link.

Changed: the file as published is an Adobe Illustrator export whose DTD entity
declarations and Adobe namespace attributes stop it being parsed here. Those
were expanded and removed. The drawing is untouched — every path is
byte-identical to the published file.''';

const _gentoo = '''
The Gentoo "g" signet — (c) Gentoo Foundation and Lennart Andre Rolland.
https://www.gentoo.org/inside-gentoo/artwork/gentoo-logo.html

Licensed under the Creative Commons Attribution-ShareAlike 2.5 License
(https://creativecommons.org/licenses/by-sa/2.5/), which is the licence Gentoo
states for the vector versions of its logo.''';

const _nixos = '''
The NixOS logo — by the NixOS Project and contributors (Simon Frankau, Tim
Cuthbertson, Daniel Baker).
https://github.com/NixOS/nixos-artwork

Licensed under the Creative Commons Attribution 4.0 International License
(https://creativecommons.org/licenses/by/4.0/). The authors' consent to that
licence is recorded in NixOS/branding under docs/provenance/.''';

const _alpine = '''
The Alpine Linux mark — Alpine Linux.
https://alpinelinux.org/

No copyright licence, because none is needed: the mark consists only of simple
geometric shapes, which do not meet the threshold of originality for copyright
protection. It is filed as such on Wikimedia Commons
(https://commons.wikimedia.org/wiki/File:Alpine_Linux.svg). It remains a
trademark of the Alpine Linux Development Team.''';
