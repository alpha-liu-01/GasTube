import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/storage_paths.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/infrastructure/settings/newpipe_data_service.dart';
import 'package:fluxtube/core/di/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

class BackupSettingsSection extends StatelessWidget {
  const BackupSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final S locals = S.of(context);

    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) =>
          previous.currentProfile != current.currentProfile ||
          previous.lastExportedFilePath != current.lastExportedFilePath,
      builder: (context, settingsState) {
        final currentProfile = settingsState.currentProfile;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locals.backupRestore,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 16),
            ),
            if (currentProfile != 'default')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Profile: $currentProfile',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            kHeightBox10,
            // NewPipe compatible export (ZIP)
            ListTile(
              title: Text(locals.exportSubscriptions,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text('Export as NewPipe-compatible ZIP (subscriptions, history, saved)'),
              leading: const Icon(Icons.archive_outlined),
              onTap: () async {
                await _exportAsZip(context, currentProfile, locals);
              },
            ),
            // Import from NewPipe ZIP
            ListTile(
              title: Text(locals.importSubscriptions,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text(
                  'Import from a NewPipe, FluxTube, or GasTube ZIP file'),
              leading: const Icon(Icons.unarchive_outlined),
              onTap: () async {
                await _importFromZip(context, currentProfile, locals);
              },
            ),
            const Divider(),
            // Legacy JSON export (for backwards compatibility)
            ListTile(
              title: Text('${locals.exportSubscriptions} (JSON)',
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(locals.backupRestoreDescription),
              leading: const Icon(Icons.upload_outlined, size: 20),
              dense: true,
              onTap: () async {
                await _exportSubscriptionsJson(context, currentProfile, locals);
              },
            ),
            // Legacy JSON import
            ListTile(
              title: Text('${locals.importSubscriptions} (JSON)',
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(locals.selectFile),
              leading: const Icon(Icons.download_outlined, size: 20),
              dense: true,
              onTap: () async {
                await _importSubscriptionsJson(context, currentProfile, locals);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportAsZip(
      BuildContext context, String currentProfile, S locals) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            const Text('Exporting data...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final dataService = getIt<NewPipeDataService>();
      final result = await dataService.exportAsNewPipeZip(
        profileName: currentProfile,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${failure.toString()}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        (filePath) {
          // Update settings bloc with the exported file path
          BlocProvider.of<SettingsBloc>(context).add(
            SettingsEvent.setLastExportedFilePath(filePath: filePath),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            _exportSnackBar(locals, filePath),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importFromZip(
      BuildContext context, String currentProfile, S locals) async {
    try {
      final filePath = await _chooseImportFile(
        context,
        locals,
        allowedExtensions: const ['zip'],
      );
      if (filePath == null) return;

      // Show import options dialog
      if (!context.mounted) return;
      final options = await _showImportOptionsDialog(context);
      if (options == null) return; // User cancelled

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                const Text('Importing data...'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final dataService = getIt<NewPipeDataService>();
      final importResult = await dataService.importFromNewPipeZip(
        zipPath: filePath,
        profileName: currentProfile,
        importSubscriptions: options['subscriptions'] ?? true,
        importSearchHistory: options['searchHistory'] ?? true,
        importWatchHistory: options['watchHistory'] ?? true,
        importPlaylists: options['playlists'] ?? true,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      importResult.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import failed: ${failure.toString()}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported: ${result.subscriptionsImported} subscriptions, '
                '${result.searchHistoryImported} searches, '
                '${result.watchHistoryImported} history items, '
                '${result.playlistsImported} saved videos',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );

          // Refresh subscriptions
          BlocProvider.of<SubscribeBloc>(context).add(
            const SubscribeEvent.getAllSubscribeList(),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${locals.importError}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Map<String, bool>?> _showImportOptionsDialog(BuildContext context) async {
    bool importSubscriptions = true;
    bool importSearchHistory = true;
    bool importWatchHistory = true;
    bool importPlaylists = true;

    return showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Subscriptions'),
                subtitle: const Text('YouTube channel subscriptions'),
                value: importSubscriptions,
                onChanged: (v) => setState(() => importSubscriptions = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Search History'),
                subtitle: const Text('Previous search queries'),
                value: importSearchHistory,
                onChanged: (v) => setState(() => importSearchHistory = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Watch History'),
                subtitle: const Text('Previously watched videos'),
                value: importWatchHistory,
                onChanged: (v) => setState(() => importWatchHistory = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Saved Videos'),
                subtitle: const Text('Playlist items as saved videos'),
                value: importPlaylists,
                onChanged: (v) => setState(() => importPlaylists = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'subscriptions': importSubscriptions,
                'searchHistory': importSearchHistory,
                'watchHistory': importWatchHistory,
                'playlists': importPlaylists,
              }),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  // Legacy JSON export
  Future<void> _exportSubscriptionsJson(
      BuildContext context, String currentProfile, S locals) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            const Text('Exporting...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    final settingsBloc = BlocProvider.of<SettingsBloc>(context);
    settingsBloc.add(SettingsEvent.exportSubscriptions(profileName: currentProfile));

    await Future.delayed(const Duration(milliseconds: 800));

    final exportedFilePath = settingsBloc.state.lastExportedFilePath;

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (exportedFilePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _exportSnackBar(locals, exportedFilePath),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locals.exportSuccess),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Legacy JSON import
  Future<void> _importSubscriptionsJson(
      BuildContext context, String currentProfile, S locals) async {
    try {
      final filePath = await _chooseImportFile(
        context,
        locals,
        allowedExtensions: const ['json'],
      );
      if (filePath == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                const Text('Importing...'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (!context.mounted) return;
      BlocProvider.of<SettingsBloc>(context).add(
        SettingsEvent.importSubscriptions(
          filePath: filePath,
          profileName: currentProfile,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locals.importSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );

        BlocProvider.of<SubscribeBloc>(context).add(
          const SubscribeEvent.getAllSubscribeList(),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${locals.importError}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  SnackBar _exportSnackBar(S locals, String filePath) {
    final name = p.basename(filePath);
    if (UbuntuTouch.enabled) {
      return SnackBar(
        content: Text(locals.exportInsideApp(name)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      );
    }
    return SnackBar(
      content: Text(locals.exportSuccess),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: locals.share,
        onPressed: () async {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(filePath)]),
          );
        },
      ),
    );
  }

  Future<String?> _chooseImportFile(
    BuildContext context,
    S locals, {
    required List<String> allowedExtensions,
  }) async {
    if (UbuntuTouch.enabled) {
      final dir = await ubuntuTouchExportsDirectory();
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final extension = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (allowedExtensions.contains(extension)) files.add(entity);
      }
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      if (!context.mounted) return null;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locals.noFileInsideApp),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      return showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(locals.chooseFileInsideApp),
          children: [
            for (final file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, file.path),
                child: Text(p.basename(file.path)),
              ),
          ],
        ),
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final filePath = result.files.first.path;
    if (filePath == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locals.importError),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return filePath;
  }
}
