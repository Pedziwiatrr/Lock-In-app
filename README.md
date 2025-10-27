# Lock In – Productivity Tracker

**Available on Google Play Store:** [Lock In – Productivity Tracker](https://play.google.com/store/apps/details?id=io.github.pedziwiatrr.lockin)

---

## Project Description

Lock In – Productivity Tracker is a Flutter-based mobile application designed to track personal activities and goals. It allows users to monitor time spent on tasks (e.g., study, work) and completion counts for checkable activities (e.g., going to the gym). The app supports setting daily, weekly, and monthly goals, displaying statistics, and reviewing activity history.

---

## Features

- **Activity Tracking:** Record time (timer) for timed activities or completion counts for checkable tasks.  
- **Goals:** Define goals for each activity with type (daily, weekly, monthly) and start/end dates.  
- **Statistics:** Bar charts (using `fl_chart`) showing time and completions over selected periods (day, week, month, all-time). Tracks streaks and provides additional motivational statistics.  
- **History:** Review activity history and goal progress by day, with visual representation of achievements.  
- **Activity Management:** Add, edit, delete, and reorder up to 10 activities.  
- **Settings:** Customize app preferences, manage data, and access app information.  
- **Data Persistence:** Store activities, logs, and goals using `SharedPreferences`.

---

## Project Structure

### Models (`models/`)
- `activity.dart`: Abstract `Activity` class with `TimedActivity` and `CheckableActivity`.  
- `goal.dart`: `Goal` class for daily, weekly, and monthly goals.  
- `activity_log.dart`: `ActivityLog` for storing activity logs.  

### Pages (`pages/`)
- `home_page.dart`: Main page with tabs (Tracker, Goals, Activities, Stats, History).  
- `tracker_page.dart`: Interface for activity tracking (timer, manual adjustments).  
- `goals_page.dart`: Set and edit activity goals.  
- `activities_page.dart`: Manage activity list.  
- `stats_page.dart`: Visualize statistics with charts.  
- `history_page.dart`: View history and goal progress.  
- `settings_page.dart`: Theme and data reset settings.  

### Utils (`utils/`)
- `format_utils.dart`: Time formatting function (HH:mm:ss).  
- `ad_manager.dart`: AdMob ad management.  

---

## Requirements

- Flutter SDK (recommended: latest stable version)  
- Dependencies:  
  - `shared_preferences` – data storage  
  - `fl_chart` – statistics visualization  
  - `flutter/services` – input filtering  

---

## Installation

```bash
git clone https://github.com/Pedziwiatrr/Lock-In-app
flutter pub get
flutter run
