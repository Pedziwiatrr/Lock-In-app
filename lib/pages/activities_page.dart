import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../utils/ad_manager.dart';

class ActivitiesPage extends StatefulWidget {
  final List<Activity> activities;
  final VoidCallback onUpdate;
  final int launchCount;

  const ActivitiesPage({
    super.key,
    required this.activities,
    required this.onUpdate,
    required this.launchCount,
  });

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  bool _isTimedActivity = true;
  static const int maxActivities = 10;
  static const int maxNameLength = 50;
  final AdManager _adManager = AdManager.instance;
  //bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    //print('ActivitiesPage initState: launchCount = ${widget.launchCount}');
    /*
    if (widget.launchCount > 1) {
      //print('ActivitiesPage: Attempting to load banner ad');
      _adManager.loadBannerAd(onAdLoaded: (isLoaded) {
        if (mounted) {
          setState(() {
            _isAdLoaded = isLoaded;
          });
        }
      });
    } else {
      //print('ActivitiesPage: Skipping ad load due to launchCount <= 1');
    }*/
  }

  void addActivity() {
    if (widget.activities.length >= maxActivities) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 activities allowed.')),
      );
      return;
    }

    final controller = TextEditingController();
    _isTimedActivity = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline),
              SizedBox(width: 8),
              Text('Add Activity'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration:
                const InputDecoration(hintText: 'Activity name (max 50 chars)'),
                maxLength: maxNameLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxNameLength),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Timed'),
                    icon: Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Checkable'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                ],
                selected: {_isTimedActivity},
                onSelectionChanged: (Set<bool> newSelection) {
                  setDialogState(() {
                    _isTimedActivity = newSelection.first;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty &&
                    name.length <= maxNameLength &&
                    !widget.activities.any((a) => a.name == name)) {


                  _adManager.incrementGoalAddCount().then((_) {
                    if (_adManager.shouldShowGoalAd()) {
                      //print("Attempting to show rewarded ad for adding activity");
                      _adManager.showRewardedAd(
                        onUserEarnedReward: () {
                          setState(() {
                            widget.activities.add(_isTimedActivity
                                ? TimedActivity(name: name)
                                : CheckableActivity(name: name));
                          });
                          //print('Added activity: $name (${_isTimedActivity ? 'Timed' : 'Checkable'})');
                          widget.onUpdate();
                          Navigator.pop(context);
                        },
                        onAdDismissed: () {
                          //print("Ad dismissed, activity not added");
                        },
                        onAdFailedToShow: () {
                          setState(() {
                            widget.activities.add(_isTimedActivity
                                ? TimedActivity(name: name)
                                : CheckableActivity(name: name));
                          });
                          //print('Added activity: $name (${_isTimedActivity ? 'Timed' : 'Checkable'})');
                          widget.onUpdate();
                          Navigator.pop(context);
                        },
                      );
                    } else {
                      setState(() {
                        widget.activities.add(_isTimedActivity
                            ? TimedActivity(name: name)
                            : CheckableActivity(name: name));
                      });
                      //print('Added activity: $name (${_isTimedActivity ? 'Timed' : 'Checkable'})');
                      widget.onUpdate();
                      Navigator.pop(context);
                    }
                  });
                } else if (name.length > maxNameLength) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Activity name must be 50 characters or less.')),
                  );
                } else if (widget.activities.any((a) => a.name == name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity name already exists.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid activity name.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void renameActivity(int index) {
    final controller = TextEditingController(text: widget.activities[index].name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('Rename Activity'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name (max 50 chars)'),
          maxLength: maxNameLength,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxNameLength),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty &&
                  name.length <= maxNameLength &&
                  !widget.activities.any((a) => a.name == name)) {
                _adManager.incrementActivityChangeCount().then((_) {
                  if (_adManager.shouldShowActivityChangeAd()) {
                    //print("Attempting to show rewarded ad for activity rename");
                    _adManager.showRewardedAd(
                      onUserEarnedReward: () {
                        setState(() {
                          widget.activities[index].name = name;
                        });
                        //print('Renamed activity to: $name');
                        widget.onUpdate();
                        Navigator.pop(context);
                      },
                      onAdDismissed: () {
                        //print("Ad dismissed, activity not renamed");
                      },
                      onAdFailedToShow: () {
                        //print("Ad failed to show, activity not renamed");
                      },
                    );
                  } else {
                    setState(() {
                      widget.activities[index].name = name;
                    });
                    //print('Renamed activity to: $name');
                    widget.onUpdate();
                    Navigator.pop(context);
                  }
                });
              } else if (name.length > maxNameLength) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Activity name must be 50 characters or less.')),
                );
              } else if (widget.activities.any((a) => a.name == name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Activity name already exists.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid activity name.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void deleteActivity(int index) {
    final name = widget.activities[index].name;
    _adManager.incrementActivityChangeCount().then((_) {
      if (_adManager.shouldShowActivityChangeAd()) {
        //print("Attempting to show rewarded ad for activity deletion");
        _adManager.showRewardedAd(
          onUserEarnedReward: () {
            setState(() {
              widget.activities.removeAt(index);
            });
            //print('Deleted activity: $name');
            widget.onUpdate();
          },
          onAdDismissed: () {
            //print("Ad dismissed, activity not deleted");
          },
          onAdFailedToShow: () {
            //print("Ad failed to show, activity not deleted");
          },
        );
      } else {
        setState(() {
          widget.activities.removeAt(index);
        });
        //print('Deleted activity: $name');
        widget.onUpdate();
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final activity = widget.activities.removeAt(oldIndex);
      widget.activities.insert(newIndex, activity);
    });
    //print('Reordered activities');
    widget.onUpdate();
  }

  @override
  void dispose() {
    //print('ActivitiesPage: Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReorderableListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
            .copyWith(bottom: 88),
        onReorder: _onReorder,
        children: widget.activities.asMap().entries.map((entry) {
          final index = entry.key;
          final a = entry.value;
          return Card(
            key: ValueKey(a.name),
            child: ListTile(
              leading: Icon(
                a is TimedActivity
                    ? Icons.timer_outlined
                    : Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(a.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => renameActivity(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => deleteActivity(index),
                  ),
                  const Icon(Icons.drag_handle),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addActivity,
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}