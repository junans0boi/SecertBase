import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 앱 기본 언어는 한국어다. 날짜·시간 선택기 같은 Material 위젯 문구가 여기서 정해진다.
const Locale kAppLocale = Locale('ko', 'KR');

const List<Locale> kAppSupportedLocales = [Locale('ko', 'KR')];

const List<LocalizationsDelegate<dynamic>> kAppLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
