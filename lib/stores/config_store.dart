import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:lemmy_api_client/v3.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../util/async_store.dart';
import '../util/mobx_provider.dart';

part 'config_store.g.dart';

/// Store managing user-level configuration such as theme or language
@JsonSerializable()
@LocaleConverter()
class ConfigStore extends _ConfigStore with _$ConfigStore, DisposableStore {
  static const _prefsKey = 'v1:ConfigStore';
  late final SharedPreferences _sharedPrefs;

  @visibleForTesting
  ConfigStore();

  factory ConfigStore.load(SharedPreferences sharedPrefs) {
    final store = _$ConfigStoreFromJson(
      jsonDecode(sharedPrefs.getString(_prefsKey) ?? '{}')
          as Map<String, dynamic>,
    ).._sharedPrefs = sharedPrefs;

    store.addReaction(autorun((_) => store.save()));

    return store;
  }

  Future<void> save() async {
    final serialized = jsonEncode(_$ConfigStoreToJson(this));

    await _sharedPrefs.setString(_prefsKey, serialized);
  }
}

abstract class _ConfigStore with Store {
  @observable
  @JsonKey(defaultValue: ThemeMode.system)
  ThemeMode theme = ThemeMode.system;

  @observable
  @JsonKey(defaultValue: false)
  bool amoledDarkMode = false;

  // default value is set in the `LocaleConverter.fromJson`
  @observable
  Locale locale = const Locale('en');

  // post style
  @observable
  @JsonKey(defaultValue: false)
  bool compactPostView = false;

  @observable
  @JsonKey(defaultValue: true)
  bool postRoundedCorners = true;

  @observable
  @JsonKey(defaultValue: true)
  bool postCardShadow = true;

  @observable
  @JsonKey(defaultValue: true)
  bool showAvatars = true;

  @observable
  @JsonKey(defaultValue: true)
  bool showScores = true;

  @observable
  @JsonKey(defaultValue: true)
  bool blurNsfw = true;

  /// Allows the user to see the combined EVERYTHING feed, which can be
  /// confusing, so default it off.
  @observable
  @JsonKey(defaultValue: false)
  bool showEverythingFeed = false;

  // default is set in fromJson
  @observable
  @JsonKey(fromJson: _sortTypeFromJson)
  SortType defaultSortType = SortType.hot;

  // default is set in fromJson
  @observable
  @JsonKey(fromJson: _postListingTypeFromJson)
  PostListingType defaultListingType = PostListingType.all;

  final lemmyImportState = AsyncStore<FullSiteView>();

  /// Copies over settings from lemmy to [ConfigStore]
  @action
  void copyLemmyUserSettings(LocalUserSettings localUserSettings) {
    // themes from lemmy-ui that are dark mode
    const darkModeLemmyUiThemes = {
      'solar',
      'cyborg',
      'darkly',
      'vaporwave-dark',
      'i386',
    };

    showAvatars = localUserSettings.showAvatars;
    theme = () {
      if (localUserSettings.theme == 'browser') return ThemeMode.system;

      if (darkModeLemmyUiThemes.contains(localUserSettings.theme)) {
        return ThemeMode.dark;
      }

      return ThemeMode.light;
    }();

    if (L10n.supportedLocales
        .contains(Locale(localUserSettings.interfaceLanguage))) {
      locale = Locale(localUserSettings.interfaceLanguage);
    }

    showScores = localUserSettings.showScores;
    defaultSortType = localUserSettings.defaultSortType ?? SortType.active;
    defaultListingType =
        localUserSettings.defaultListingType ?? PostListingType.all;
  }

  /// Fetches [LocalUserSettings] and imports them with [.copyLemmyUserSettings]
  @action
  Future<void> importLemmyUserSettings(Jwt token) async {
    final site = await lemmyImportState.runLemmy(
      token.payload.iss,
      GetSite(auth: token.raw),
    );

    if (site != null) {
      copyLemmyUserSettings(site.myUser!.localUserView.localUser);
    }
  }
}

SortType _sortTypeFromJson(String? json) =>
    json != null ? SortType.fromJson(json) : SortType.hot;
PostListingType _postListingTypeFromJson(String? json) =>
    json != null ? PostListingType.fromJson(json) : PostListingType.all;
