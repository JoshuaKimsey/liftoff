import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:lemmy_api_client/v3.dart';

import '../../hooks/stores.dart';
import '../../l10n/l10n.dart';
import '../../stores/config_store.dart';
import '../../util/async_store_listener.dart';
import '../../util/goto.dart';
import '../../util/observer_consumers.dart';
import '../../widgets/about_tile.dart';
import '../../widgets/bottom_modal.dart';
import '../../widgets/radio_picker.dart';
import '../manage_account.dart';
import 'add_account_page.dart';
import 'add_instance_page.dart';
import 'blocks/blocks.dart';

/// Page with a list of different settings sections
class SettingsPage extends HookWidget {
  const SettingsPage();

  @override
  Widget build(BuildContext context) {
    final hasAnyUsers = useAccountsStoreSelect((store) => !store.hasNoAccount);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('General'),
            onTap: () {
              goTo(context, (_) => const GeneralConfigPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Accounts'),
            onTap: () {
              goTo(context, (_) => AccountsConfigPage());
            },
          ),
          if (hasAnyUsers)
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocks'),
              onTap: () {
                Navigator.of(context).push(BlocksPage.route());
              },
            ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Appearance'),
            onTap: () {
              goTo(context, (_) => const AppearanceConfigPage());
            },
          ),
          const AboutTile()
        ],
      ),
    );
  }
}

/// Settings for theme color, AMOLED switch
class AppearanceConfigPage extends StatelessWidget {
  const AppearanceConfigPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ObserverBuilder<ConfigStore>(
        builder: (context, store) => ListView(
          children: [
            const _SectionHeading('Theme'),
            for (final theme in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: theme,
                title: Text(theme.name),
                groupValue: store.theme,
                onChanged: (selected) {
                  if (selected != null) store.theme = selected;
                },
              ),
            SwitchListTile.adaptive(
              title: const Text('AMOLED dark mode'),
              value: store.amoledDarkMode,
              onChanged: (checked) {
                store.amoledDarkMode = checked;
              },
            ),
            const SizedBox(height: 12),
            const _SectionHeading('Post Style'),
            SwitchListTile.adaptive(
              title: Text(L10n.of(context).post_style_compact),
              value: store.compactPostView,
              onChanged: (checked) {
                store.compactPostView = checked;
              },
            ),
            SwitchListTile.adaptive(
              title: Text(L10n.of(context).post_style_rounded_corners),
              value: store.postRoundedCorners,
              onChanged: (checked) {
                store.postRoundedCorners = checked;
              },
            ),
            SwitchListTile.adaptive(
              title: Text(L10n.of(context).post_style_shadow),
              value: store.postCardShadow,
              onChanged: (checked) {
                store.postCardShadow = checked;
              },
            ),
            const SizedBox(height: 12),
            const _SectionHeading('Other'),
            SwitchListTile.adaptive(
              title: Text(L10n.of(context).show_avatars),
              value: store.showAvatars,
              onChanged: (checked) {
                store.showAvatars = checked;
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('Show scores'),
              value: store.showScores,
              onChanged: (checked) {
                store.showScores = checked;
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('Blur NSFW'),
              subtitle: const Text('Images in NSFW posts will be hidden.'),
              value: store.blurNsfw,
              onChanged: (checked) {
                store.blurNsfw = checked;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// General settings
class GeneralConfigPage extends StatelessWidget {
  const GeneralConfigPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('General')),
      body: ObserverBuilder<ConfigStore>(
        builder: (context, store) => ListView(
          children: [
            ListTile(
              title: Text(L10n.of(context).sort_type),
              trailing: SizedBox(
                width: 120,
                child: RadioPicker<SortType>(
                  values: SortType.values,
                  groupValue: store.defaultSortType,
                  onChanged: (value) => store.defaultSortType = value,
                  mapValueToString: (value) => value.value,
                ),
              ),
            ),
            ListTile(
              title: Text(L10n.of(context).type),
              trailing: SizedBox(
                width: 120,
                child: RadioPicker<PostListingType>(
                  values: const [
                    PostListingType.all,
                    PostListingType.local,
                    PostListingType.subscribed,
                  ],
                  groupValue: store.defaultListingType,
                  onChanged: (value) => store.defaultListingType = value,
                  mapValueToString: (value) => value.value,
                ),
              ),
            ),
            ListTile(
              title: Text(L10n.of(context).language),
              trailing: SizedBox(
                width: 120,
                child: RadioPicker<Locale>(
                  title: 'Choose language',
                  groupValue: store.locale,
                  values: L10n.supportedLocales,
                  mapValueToString: (locale) => locale.languageName,
                  onChanged: (selected) {
                    store.locale = selected;
                  },
                ),
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('Show EVERYTHING feed'),
              subtitle:
                  const Text('This will combine content from all instances, '
                      "even those you're not signed into, so you may "
                      "see posts you can't vote on or reply to."),
              value: store.showEverythingFeed,
              onChanged: (checked) {
                store.showEverythingFeed = checked;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Popup for an account
class _AccountOptions extends HookWidget {
  final String instanceHost;
  final String username;

  const _AccountOptions({
    required this.instanceHost,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final accountsStore = useAccountsStore();

    Future<void> removeUserDialog(String instanceHost, String username) async {
      if (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove user?'),
              content: Text(
                  'Are you sure you want to remove $username@$instanceHost?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(L10n.of(context).no),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(L10n.of(context).yes),
                ),
              ],
            ),
          ) ??
          false) {
        await accountsStore.removeAccount(instanceHost, username);
        Navigator.of(context).pop();
      }
    }

    return Column(
      children: [
        if (accountsStore.defaultUsernameFor(instanceHost) != username)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Set as default'),
            onTap: () {
              accountsStore.setDefaultAccountFor(instanceHost, username);
              Navigator.of(context).pop();
            },
          ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text('Remove account'),
          onTap: () => removeUserDialog(instanceHost, username),
        ),
        AsyncStoreListener(
          asyncStore: context.read<ConfigStore>().lemmyImportState,
          successMessageBuilder: (context, data) => 'Import successful',
          child: ObserverBuilder<ConfigStore>(
            builder: (context, store) => ListTile(
              leading: store.lemmyImportState.isLoading
                  ? const SizedBox(
                      height: 25,
                      width: 25,
                      child: CircularProgressIndicator.adaptive(),
                    )
                  : const Icon(Icons.cloud_download),
              title: const Text('Import settings to Liftoff'),
              onTap: () async {
                await context.read<ConfigStore>().importLemmyUserSettings(
                      accountsStore.userDataFor(instanceHost, username)!.jwt,
                    );
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Settings for managing accounts
class AccountsConfigPage extends HookWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsStore = useAccountsStore();

    removeInstanceDialog(String instanceHost) async {
      if (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove instance?'),
              content: Text('Are you sure you want to remove $instanceHost?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(L10n.of(context).no),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(L10n.of(context).yes),
                ),
              ],
            ),
          ) ??
          false) {
        await accountsStore.removeInstance(instanceHost);
        Navigator.of(context).pop();
      }
    }

    void accountActions(String instanceHost, String username) {
      showBottomModal(
        context: context,
        builder: (context) => _AccountOptions(
          instanceHost: instanceHost,
          username: username,
        ),
      );
    }

    void instanceActions(String instanceHost) {
      showBottomModal(
        context: context,
        builder: (context) => Column(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove instance'),
              onTap: () => removeInstanceDialog(instanceHost),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close, // TODO: change to + => x
        curve: Curves.bounceIn,
        tooltip: 'Add account or instance',
        children: [
          SpeedDialChild(
            child: const Icon(Icons.person_add),
            label: 'Add account',
            onTap: () => Navigator.of(context)
                .push(AddAccountPage.route(accountsStore.instances.last)),
          ),
          SpeedDialChild(
            child: const Icon(Icons.dns),
            label: 'Add instance',
            onTap: () => Navigator.of(context).push(AddInstancePage.route()),
          ),
        ],
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          if (accountsStore.instances.isEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(AddInstancePage.route()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add instance'),
                  ),
                ),
              ],
            ),
          for (final instance in accountsStore.instances) ...[
            const SizedBox(height: 40),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onLongPress: () => instanceActions(instance),
              title: _SectionHeading(instance),
            ),
            for (final username in accountsStore.usernamesFor(instance)) ...[
              ListTile(
                trailing: username == accountsStore.defaultUsernameFor(instance)
                    ? Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.secondary,
                      )
                    : null,
                title: Text(username),
                onLongPress: () => accountActions(instance, username),
                onTap: () {
                  goTo(
                      context,
                      (_) => ManageAccountPage(
                            instanceHost: instance,
                            username: username,
                          ));
                },
              ),
            ],
            if (accountsStore.usernamesFor(instance).isEmpty)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add account'),
                onTap: () {
                  Navigator.of(context).push(AddAccountPage.route(instance));
                },
              ),
          ]
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;

  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Text(text.toUpperCase(),
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.secondary)),
    );
  }
}
